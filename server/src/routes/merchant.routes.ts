import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { requireAuth, requireMerchant } from '../middleware/auth';
import { validate } from '../middleware/validate';
import { Merchant } from '../models/Merchant';
import { User } from '../models/User';
import { Invoice } from '../models/Invoice';
import { upstashRedis, cacheKeys, cacheTtl } from '../config/redis';
import { logger } from '../config/logger';

const router = Router();

async function generateMerchantId(): Promise<string> {
  const counter = await upstashRedis.incr('merchant:id:counter');
  return `MC-${String(counter + 1000).padStart(4, '0')}`;
}

const walletAddressSchema = z.string()
  .refine((val) => !val.startsWith('stake'), {
    message: 'Stake addresses are not supported',
  })
  .refine((val) => /^addr(_test)?1[a-z0-9]+$/.test(val), {
    message: 'Invalid payment address format',
  });

const onboardSchema = z.object({
  shopName: z.string().min(2).max(50).trim(),
  category: z.enum(['food', 'retail', 'services', 'vendor', 'other']),
  description: z.string().max(200).trim().optional(),
  walletAddress: walletAddressSchema,
  walletProvider: z.string().min(1).trim(),
});

const settingsSchema = z.object({
  shopName: z.string().min(2).max(50).trim().optional(),
  category: z.enum(['food', 'retail', 'services', 'vendor', 'other']).optional(),
  description: z.string().max(200).trim().optional(),
  invoiceExpiry: z.number().int().min(300).max(1800).optional(),
});

const walletSchema = z.object({
  walletAddress: walletAddressSchema,
  stakeAddress: z.string().optional(),
});

// POST /api/v1/merchant/onboard
router.post(
  '/onboard',
  requireAuth,
  validate(onboardSchema),
  async (req: Request, res: Response): Promise<void> => {
    const requestId = res.locals['requestId'] as string | undefined;
    try {
      const existing = await Merchant.findOne({ userId: req.user.id });
      if (existing) {
        logger.warn('Merchant onboarding failed — profile already exists', {
          requestId,
          userId: req.user.id,
        });
        res.status(409).json({ success: false, error: 'Merchant profile already exists', requestId });
        return;
      }

      const { shopName, category, description, walletAddress, walletProvider } = req.body as z.infer<typeof onboardSchema>;

      logger.info('Onboard merchant request received', {
        requestId,
        userId: req.user.id,
        shopName,
        category,
        walletProvider,
        walletAddress,
      });

      const merchantId = await generateMerchantId();

      const merchant = await Merchant.create({
        userId: req.user.id,
        merchantId,
        shopName,
        category,
        description,
        paymentAddress: walletAddress,
        invoiceExpiry: 600,
      });

      // Update user role, onboardingStep, and wallet details
      await User.findByIdAndUpdate(req.user.id, {
        $set: {
          walletAddress,
          walletProvider,
          role: req.user.role === 'customer' ? 'both' : 'merchant',
          onboardingStep: 'complete',
        },
      });

      logger.info('Merchant onboarded successfully', {
        requestId,
        userId: req.user.id,
        merchantId: merchant.merchantId,
        shopName: merchant.shopName,
        walletAddress,
        walletProvider,
      });

      res.status(201).json({
        success: true,
        data: {
          merchantId: merchant.merchantId,
          shopName: merchant.shopName,
          category: merchant.category,
          paymentAddress: merchant.paymentAddress,
        },
        requestId,
      });
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Onboarding failed';
      logger.error('Merchant onboarding failed with error', {
        requestId,
        userId: req.user.id,
        detail: message,
      });
      res.status(400).json({ success: false, error: message, requestId });
    }
  }
);

// GET /api/v1/merchant/:merchantId — Public profile (for QR scan)
router.get('/:merchantId', async (req: Request, res: Response): Promise<void> => {
  try {
    const { merchantId } = req.params;

    // Check cache first
    const cached = await upstashRedis.get(cacheKeys.merchantProfile(merchantId));
    if (cached) {
      res.json({ success: true, data: cached, source: 'cached' });
      return;
    }

    const merchant = await Merchant.findOne({ merchantId, isActive: true }).lean();
    if (!merchant) {
      res.status(404).json({ success: false, error: 'Merchant not found' });
      return;
    }

    const publicProfile = {
      merchantId: merchant.merchantId,
      shopName: merchant.shopName,
      category: merchant.category,
      description: merchant.description,
      paymentAddress: merchant.paymentAddress,
      invoiceExpiry: merchant.invoiceExpiry,
    };

    await upstashRedis.set(cacheKeys.merchantProfile(merchantId), publicProfile, {
      ex: cacheTtl.merchantProfile,
    });

    res.json({ success: true, data: publicProfile });
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Failed to fetch merchant';
    res.status(500).json({ success: false, error: message });
  }
});

// PUT /api/v1/merchant/settings
router.put(
  '/settings',
  requireAuth,
  requireMerchant,
  validate(settingsSchema),
  async (req: Request, res: Response): Promise<void> => {
    try {
      const merchant = await Merchant.findOne({ userId: req.user.id });
      if (!merchant) {
        res.status(404).json({ success: false, error: 'Merchant profile not found' });
        return;
      }

      const updates = req.body as z.infer<typeof settingsSchema>;
      if (updates.shopName) merchant.shopName = updates.shopName;
      if (updates.category) merchant.category = updates.category;
      if (updates.description !== undefined) merchant.description = updates.description;
      if (updates.invoiceExpiry) merchant.invoiceExpiry = updates.invoiceExpiry;

      await merchant.save();

      // Invalidate cache
      await upstashRedis.del(cacheKeys.merchantProfile(merchant.merchantId));

      res.json({ success: true, data: { merchantId: merchant.merchantId, shopName: merchant.shopName } });
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Update failed';
      res.status(400).json({ success: false, error: message });
    }
  }
);

// POST /api/v1/merchant/wallet — Connect/update wallet address
router.post(
  '/wallet',
  requireAuth,
  validate(walletSchema),
  async (req: Request, res: Response): Promise<void> => {
    const requestId = res.locals['requestId'] as string | undefined;
    try {
      const { walletAddress, stakeAddress } = req.body as z.infer<typeof walletSchema>;

      logger.info('Connect/update wallet request received', {
        requestId,
        userId: req.user.id,
        walletAddress,
        stakeAddress,
      });

      const nextStep =
        req.user.onboardingStep === 'role-selected' || req.user.onboardingStep === 'new'
          ? 'wallet-complete'
          : req.user.onboardingStep;

      await User.findByIdAndUpdate(req.user.id, {
        $set: {
          walletAddress,
          stakeAddress,
          onboardingStep: nextStep,
        },
      });

      // If merchant exists, update their payment address too
      const merchant = await Merchant.findOneAndUpdate(
        { userId: req.user.id },
        { $set: { paymentAddress: walletAddress } },
        { new: true }
      );

      if (merchant) {
        await upstashRedis.del(cacheKeys.merchantProfile(merchant.merchantId));
      }

      logger.info('Wallet connected/updated successfully', {
        requestId,
        userId: req.user.id,
        walletAddress,
      });

      res.json({ success: true, data: { walletAddress }, requestId });
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Wallet update failed';
      logger.error('Wallet connect/update failed', {
        requestId,
        userId: req.user.id,
        detail: message,
      });
      res.status(400).json({ success: false, error: message, requestId });
    }
  }
);

// GET /api/v1/merchant/dashboard is implemented in dashboard.routes.ts


export default router;
