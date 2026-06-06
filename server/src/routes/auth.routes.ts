import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { getFirebaseAuth } from '../config/firebase-admin';
import { User } from '../models/User';
import { Merchant } from '../models/Merchant';
import { requireAuth, ensureMerchantProvisioned } from '../middleware/auth';
import { validate } from '../middleware/validate';
import { authRateLimit } from '../middleware/rateLimit';
import { upstashRedis, cacheKeys } from '../config/redis';
import { env } from '../config/env';

const router = Router();

const syncSchema = z.object({
  displayName: z.string().min(1).max(60).optional(),
  phone: z.string().regex(/^\+[1-9]\d{6,14}$/).optional(),
  fcmToken: z.string().optional(),
});

const profileSchema = z.object({
  displayName: z.string().min(1).max(60).optional(),
  fcmToken: z.string().optional(),
  notificationPreferences: z
    .object({
      paymentReceived: z.boolean().optional(),
      paymentConfirmed: z.boolean().optional(),
      invoiceExpired: z.boolean().optional(),
      escrowUpdates: z.boolean().optional(),
      disputeAlerts: z.boolean().optional(),
      milestoneNotifications: z.boolean().optional(),
      channels: z.array(z.enum(['push', 'email'])).optional(),
    })
    .optional(),
});

// POST /api/v1/auth/sync — Create or update user from Firebase token
router.post(
  '/sync',
  authRateLimit,
  async (req: Request, res: Response): Promise<void> => {
    try {
      const authHeader = req.headers.authorization;
      if (!authHeader?.startsWith('Bearer ')) {
        res.status(401).json({ success: false, error: 'Missing authorization header' });
        return;
      }

      const token = authHeader.slice(7);
      let decoded: { uid: string; phone_number?: string; name?: string };

      if (token.startsWith('dev_token_')) {
        if (env.NODE_ENV === 'production' || !env.DEV_AUTH_ENABLED) {
          res.status(401).json({ success: false, error: 'Developer authentication bypass is disabled in production' });
          return;
        }
        const role = token.slice(10);
        decoded = {
          uid: `dev_uid_${role}`,
          phone_number: '+919999999999',
          name: `Dev User ${role.toUpperCase()}`,
        };
      } else {
        decoded = await getFirebaseAuth().verifyIdToken(token, true);
      }

      const body = syncSchema.safeParse(req.body);

      let user = await User.findOne({ firebaseUid: decoded.uid });

      if (!user) {
        // Auto-detect role for dev user
        const defaultRole = token.startsWith('dev_token_') ? (token.slice(10) === 'merchant' ? 'merchant' : 'customer') : 'customer';
        user = await User.create({
          firebaseUid: decoded.uid,
          phone: decoded.phone_number ?? body.data?.phone,
          displayName: body.data?.displayName ?? decoded.name ?? 'ZeroPay User',
          role: defaultRole,
          onboardingStep: token.startsWith('dev_token_') ? 'complete' : 'new',
          fcmToken: body.data?.fcmToken,
        });
      } else {
        // Update mutable fields on re-sync
        if (body.data?.displayName) user.displayName = body.data.displayName;
        if (body.data?.fcmToken) user.fcmToken = body.data.fcmToken;
        if (body.data?.phone) user.phone = body.data.phone;
        await user.save();
      }

      // Auto-heal / provision Merchant record if missing
      await ensureMerchantProvisioned(user);

      res.json({
        success: true,
        data: user,
      });
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Sync failed';
      res.status(400).json({ success: false, error: message });
    }
  }
);

// GET /api/v1/auth/me
router.get('/me', requireAuth, (req: Request, res: Response): void => {
  const { user } = req;
  res.json({
    success: true,
    data: {
      id: user.id,
      firebaseUid: user.firebaseUid,
      phone: user.phone,
      displayName: user.displayName,
      role: user.role,
      walletAddress: user.walletAddress,
      onboardingStep: user.onboardingStep,
      notificationPreferences: user.notificationPreferences,
    },
  });
});

// PUT /api/v1/auth/profile
router.put(
  '/profile',
  requireAuth,
  validate(profileSchema),
  async (req: Request, res: Response): Promise<void> => {
    try {
      const { user } = req;
      const updates = req.body as z.infer<typeof profileSchema>;

      if (updates.displayName) user.displayName = updates.displayName;
      if (updates.fcmToken) user.fcmToken = updates.fcmToken;
      if (updates.notificationPreferences) {
        user.notificationPreferences = {
          ...user.notificationPreferences,
          ...updates.notificationPreferences,
        };
      }

      await user.save();

      res.json({
        success: true,
        data: {
          id: user.id,
          firebaseUid: user.firebaseUid,
          phone: user.phone,
          displayName: user.displayName,
          role: user.role,
          walletAddress: user.walletAddress,
          onboardingStep: user.onboardingStep,
          notificationPreferences: user.notificationPreferences,
        }
      });
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Update failed';
      res.status(400).json({ success: false, error: message });
    }
  }
);

// PUT /api/v1/auth/role
router.put(
  '/role',
  requireAuth,
  async (req: Request, res: Response): Promise<void> => {
    try {
      const { role, onboardingStep } = req.body;
      const { user } = req;

      if (!role || !['customer', 'merchant', 'both'].includes(role)) {
        res.status(400).json({ success: false, error: 'Invalid role' });
        return;
      }

      const updateFields: Record<string, string> = { role };
      if (onboardingStep) {
        if (!['new', 'role-selected', 'wallet-complete', 'shop-complete', 'complete'].includes(onboardingStep)) {
          res.status(400).json({ success: false, error: 'Invalid onboarding step' });
          return;
        }
        updateFields.onboardingStep = onboardingStep;
      }

      const updatedUser = await User.findOneAndUpdate(
        { firebaseUid: user.firebaseUid },
        { $set: updateFields },
        { new: true }
      );

      res.json({
        success: true,
        data: updatedUser,
      });
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Update failed';
      res.status(400).json({ success: false, error: message });
    }
  }
);

// POST /api/v1/auth/logout
router.post(
  '/logout',
  requireAuth,
  async (req: Request, res: Response): Promise<void> => {
    try {
      const { user } = req;

      // 1. Delete associated merchant profile and invalidate its Redis cache
      const merchant = await Merchant.findOne({ userId: user.id });
      if (merchant) {
        await upstashRedis.del(cacheKeys.merchantProfile(merchant.merchantId));
        await Merchant.deleteOne({ _id: merchant._id });
      }

      // 2. Atomically reset user state on backend — source of truth
      await User.findOneAndUpdate(
        { firebaseUid: req.user.firebaseUid },
        {
          $set: {
            role: 'customer',
            onboardingStep: 'new',
            walletAddress: null,
            walletProvider: null,
            stakeAddress: null,
          },
        }
      );

      res.json({ success: true, message: 'Session reset successfully' });
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Logout failed';
      res.status(500).json({ success: false, error: message });
    }
  }
);

export default router;
