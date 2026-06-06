import { Request, Response, NextFunction } from 'express';
import { getFirebaseAuth } from '../config/firebase-admin';
import { User, IUser } from '../models/User';

// Augment Express Request to include authenticated user
declare global {
  namespace Express {
    interface Request {
      firebaseUid: string;
      user: IUser;
    }
  }
}

import { Merchant } from '../models/Merchant';
import { AIAgentConfig } from '../models/AIAgentConfig';
import { upstashRedis } from '../config/redis';

export async function ensureMerchantProvisioned(user: any): Promise<void> {
  if (user.role === 'merchant' || user.role === 'both') {
    const existingMerchant = await Merchant.findOne({ userId: user._id });
    if (!existingMerchant) {
      // Generate a new unique merchantId
      const counter = await upstashRedis.incr('merchant:id:counter');
      const merchantId = `MC-${String(counter + 1000).padStart(4, '0')}`;
      
      const shopName = `${user.displayName || 'Dev'}'s Shop`;
      const slug = `${shopName.toLowerCase().replace(/[^a-z0-9]/g, '-')}-${merchantId.toLowerCase()}`;

      const merchant = await Merchant.create({
        userId: user._id,
        merchantId,
        shopName,
        category: 'retail',
        description: 'Automatically provisioned minimum storefront',
        paymentAddress: user.walletAddress || 'addr_test1qrm9x2zsux7va6w892g38szjs7as5a92s2c67q5da0a5e8c1ab999',
        invoiceExpiry: 600,
        isActive: true,
        slug,
        profileImageUrl: 'https://images.unsplash.com/photo-1578916171728-46686eac8d58?auto=format&fit=crop&w=150&q=80',
        bannerImageUrl: 'https://images.unsplash.com/photo-1441986300917-64674bd600d8?auto=format&fit=crop&w=800&q=80',
        isPublicStorefront: true,
        location: { city: 'Bengaluru', state: 'Karnataka', country: 'India' },
        businessHours: '9 AM - 6 PM',
        socialLinks: { website: 'https://zeropay.network' },
      });

      // Also create AIAgentConfig
      await AIAgentConfig.create({
        merchantId: merchant._id,
        negotiationEnabled: true,
        minDiscountPct: 20,
        autoAcceptThresholdPct: 5,
        negotiationStyle: 'friendly',
      });

      console.log(`[auth/middleware] Auto-provisioned Merchant & Config for user ${user._id}`);
    }
  }
}

export async function requireAuth(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader?.startsWith('Bearer ')) {
      res.status(401).json({ success: false, error: 'Missing authorization header' });
      return;
    }

    const token = authHeader.slice(7);
    let decoded: { uid: string; phone_number?: string; name?: string };

    if (token.startsWith('dev_token_')) {
      const role = token.slice(10); // 'customer' or 'merchant' or 'both'
      decoded = {
        uid: `dev_uid_${role}`,
        phone_number: '+919999999999',
        name: `Dev User ${role.toUpperCase()}`,
      };
    } else {
      decoded = await getFirebaseAuth().verifyIdToken(token, true);
    }

    req.firebaseUid = decoded.uid;

    // Load MongoDB user
    let user = await User.findOne({ firebaseUid: decoded.uid });
    if (!user && token.startsWith('dev_token_')) {
      const role = token.slice(10);
      const userRole = role === 'both' ? 'both' : (role === 'merchant' ? 'merchant' : 'customer');
      user = await User.create({
        firebaseUid: decoded.uid,
        phone: decoded.phone_number,
        displayName: decoded.name,
        role: userRole,
        onboardingStep: 'complete',
      });
    }

    if (!user) {
      res.status(401).json({ success: false, error: 'User not found — call /auth/sync first' });
      return;
    }

    // Auto-heal / provision Merchant record if missing
    await ensureMerchantProvisioned(user);

    req.user = user;
    next();
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Authentication failed';
    res.status(401).json({ success: false, error: message });
  }
}

export function requireMerchant(
  req: Request,
  res: Response,
  next: NextFunction
): void {
  if (req.user.role !== 'merchant' && req.user.role !== 'both') {
    res.status(403).json({ success: false, error: 'Merchant access required' });
    return;
  }
  next();
}

export function requireCustomer(
  req: Request,
  res: Response,
  next: NextFunction
): void {
  if (req.user.role !== 'customer' && req.user.role !== 'both') {
    res.status(403).json({ success: false, error: 'Customer access required' });
    return;
  }
  next();
}

export function requireRole(role: string) {
  return function (req: Request, res: Response, next: NextFunction): void {
    if (req.user.role !== role) {
      res.status(403).json({ success: false, error: `${role} access required` });
      return;
    }
    next();
  };
}
