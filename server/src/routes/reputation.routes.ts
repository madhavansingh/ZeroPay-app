import { Router, Request, Response } from 'express';
import { requireAuth, requireMerchant } from '../middleware/auth';
import { Merchant } from '../models/Merchant';
import { Review } from '../models/Review';
import { updateMerchantReputation } from '../services/reputation.service';
import { logger } from '../config/logger';

const router = Router();

// ── GET /api/v1/reputation/:walletAddress ───────────────────────────────────
router.get('/:walletAddress', async (req: Request, res: Response) => {
  try {
    const merchant = await Merchant.findOne({
      paymentAddress: req.params.walletAddress,
      isActive: true,
    }).select('merchantId shopName slug category description reputationScore reliabilityTier verifiedMerchantBadge totalOrders escrowCompletionRate milestoneFulfillmentRate');

    if (!merchant) {
      res.status(404).json({ success: false, error: 'Merchant not found for this wallet address' });
      return;
    }

    res.json({ success: true, data: merchant });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : 'Failed to fetch reputation';
    res.status(500).json({ success: false, error: msg });
  }
});

// ── GET /api/v1/reputation/merchant/:slug ────────────────────────────────────
router.get('/merchant/:slug', async (req: Request, res: Response) => {
  try {
    const merchant = await Merchant.findOne({
      slug: req.params.slug.toLowerCase(),
      isPublicStorefront: true,
      isActive: true,
    }).select('merchantId shopName slug category description reputationScore reliabilityTier verifiedMerchantBadge totalOrders escrowCompletionRate milestoneFulfillmentRate disputeCount disputesWonCount');

    if (!merchant) {
      res.status(404).json({ success: false, error: 'Merchant storefront not found' });
      return;
    }

    // Aggregate review summary
    const reviews = await Review.find({ merchantId: merchant._id, isVerified: true });
    const count = reviews.length;
    const average = count > 0 ? parseFloat((reviews.reduce((sum, r) => sum + r.rating, 0) / count).toFixed(2)) : 0;

    res.json({
      success: true,
      data: {
        merchant,
        reviews: {
          average,
          count,
        },
      },
    });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : 'Failed to fetch storefront reputation';
    res.status(500).json({ success: false, error: msg });
  }
});

// ── POST /api/v1/reputation/refresh/:merchantId ──────────────────────────────
router.post('/refresh/:merchantId', requireAuth, requireMerchant, async (req: Request, res: Response) => {
  try {
    const merchant = await Merchant.findOne({ userId: req.user._id });
    if (!merchant) {
      res.status(404).json({ success: false, error: 'Merchant not found' });
      return;
    }

    if (merchant._id.toString() !== req.params.merchantId) {
      res.status(403).json({ success: false, error: 'Not authorized to refresh this reputation profile' });
      return;
    }

    await updateMerchantReputation(merchant._id.toString());

    const updated = await Merchant.findById(merchant._id);

    res.json({ success: true, data: updated });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : 'Failed to refresh trust metrics';
    res.status(500).json({ success: false, error: msg });
  }
});

export default router;
