import { Router, Request, Response, NextFunction } from 'express';
import { requireAuth, requireMerchant } from '../middleware/auth';
import { Invoice } from '../models/Invoice';
import { Merchant, IMerchant } from '../models/Merchant';

const router = Router();

// ─── GET /merchant/dashboard ──────────────────────────────────────────────────
router.get(
  '/dashboard',
  requireAuth,
  requireMerchant,
  async (req: Request, res: Response): Promise<void> => {
    // Lookup merchant profile for this user
    const merchant = await Merchant.findOne({ userId: req.user._id });
    if (!merchant) {
      res.status(404).json({ success: false, error: 'Merchant profile not found' });
      return;
    }

    // 7-day window
    const since = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);

    const [statusCounts, dailyRevenue, recentInvoices] = await Promise.all([
      Invoice.aggregate([
        { $match: { merchantId: merchant._id } },
        { $group: { _id: '$status', count: { $sum: 1 } } },
      ]),

      Invoice.aggregate([
        {
          $match: {
            merchantId: merchant._id,
            status: 'settled',
            settledAt: { $gte: since },
          },
        },
        {
          $group: {
            _id: { $dateToString: { format: '%Y-%m-%d', date: '$settledAt' } },
            lovelace: { $sum: '$amountLovelace' },
            paise: { $sum: '$amountPaise' },
            count: { $sum: 1 },
          },
        },
        { $sort: { _id: 1 } },
      ]),

      Invoice.find({ merchantId: merchant._id })
        .sort({ createdAt: -1 })
        .limit(20)
        .select('invoiceId amountPaise amountLovelace status createdAt settledAt txHash description')
        .lean(),
    ]);

    const stats = statusCounts.reduce<Record<string, number>>((acc, row) => {
      acc[row._id as string] = row.count as number;
      return acc;
    }, {});

    // Build 7-day revenue map with zero-fill
    const revenueByDay: Record<string, { lovelace: number; paise: number; count: number }> = {};
    for (let i = 6; i >= 0; i--) {
      const d = new Date(Date.now() - i * 24 * 60 * 60 * 1000);
      revenueByDay[d.toISOString().slice(0, 10)] = { lovelace: 0, paise: 0, count: 0 };
    }
    for (const row of dailyRevenue) {
      const key = row._id as string;
      if (revenueByDay[key]) {
        revenueByDay[key] = {
          lovelace: row.lovelace as number,
          paise: row.paise as number,
          count: row.count as number,
        };
      }
    }

    res.json({
      success: true,
      data: {
        merchant: {
          merchantId: merchant.merchantId,
          shopName: merchant.shopName,
          category: merchant.category,
          paymentAddress: merchant.paymentAddress,
          totalReceivedLovelace: merchant.totalReceivedLovelace,
          totalOrders: merchant.totalOrders,
          invoiceExpiry: merchant.invoiceExpiry,
          slug: merchant.slug,
          profileImageUrl: merchant.profileImageUrl,
          bannerImageUrl: merchant.bannerImageUrl,
          location: merchant.location,
          socialLinks: merchant.socialLinks,
          isPublicStorefront: merchant.isPublicStorefront,
          businessHours: merchant.businessHours,
          reputationScore: merchant.reputationScore,
          reliabilityTier: merchant.reliabilityTier,
        },
        stats: {
          pending: stats['pending'] ?? 0,
          submitted: stats['submitted'] ?? 0,
          confirming: stats['confirming'] ?? 0,
          confirmed: stats['confirmed'] ?? 0,
          settled: stats['settled'] ?? 0,
          expired: stats['expired'] ?? 0,
          failed: stats['failed'] ?? 0,
        },
        revenueByDay,
        recentInvoices,
        generatedAt: new Date().toISOString(),
      },
    });
  }
);

export default router;
