import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { requireAuth, requireMerchant } from '../middleware/auth';
import { validate } from '../middleware/validate';
import { Invoice } from '../models/Invoice';
import { Merchant } from '../models/Merchant';
import {
  generateMerchantInsight,
  suggestPricingForService,
  generateInvoiceDraft,
} from '../services/ai.service';
import { logger } from '../config/logger';

const router = Router();

const summaryQuerySchema = z.object({
  windowDays: z.preprocess(
    (val) => (val ? parseInt(val as string, 10) : 30),
    z.number().int().positive().max(365)
  ),
});

// ── GET /api/v1/analytics/merchant/summary ──────────────────────────────────
router.get(
  '/merchant/summary',
  requireAuth,
  requireMerchant,
  validate(summaryQuerySchema, 'query'),
  async (req: Request, res: Response): Promise<void> => {
    try {
      const { windowDays } = req.query as unknown as { windowDays: number };
      const merchant = await Merchant.findOne({ userId: req.user._id });
      if (!merchant) {
        res.status(404).json({ success: false, error: 'Merchant profile not found' });
        return;
      }

      const since = new Date(Date.now() - windowDays * 24 * 60 * 60 * 1000);

      const summary = await Invoice.aggregate([
        {
          $match: {
            merchantId: merchant._id,
            createdAt: { $gte: since },
          },
        },
        {
          $group: {
            _id: null,
            totalOrders: { $sum: 1 },
            settledOrders: { $sum: { $cond: [{ $eq: ['$status', 'settled'] }, 1, 0] } },
            totalVolumePaise: { $sum: { $cond: [{ $eq: ['$status', 'settled'] }, '$amountPaise', 0] } },
            totalVolumeLovelace: { $sum: { $cond: [{ $eq: ['$status', 'settled'] }, '$amountLovelace', 0] } },
            disputeCount: { $sum: { $cond: [{ $eq: ['$escrowState', 'Disputed'] }, 1, 0] } },
          },
        },
      ]);

      const data = summary[0] || {
        totalOrders: 0,
        settledOrders: 0,
        totalVolumePaise: 0,
        totalVolumeLovelace: 0,
        disputeCount: 0,
      };

      const averageOrderSizePaise = data.settledOrders > 0 ? Math.round(data.totalVolumePaise / data.settledOrders) : 0;
      const averageOrderSizeLovelace = data.settledOrders > 0 ? Math.round(data.totalVolumeLovelace / data.settledOrders) : 0;
      const escrowCompletionRate = data.totalOrders > 0 ? parseFloat(((data.settledOrders / data.totalOrders) * 100).toFixed(2)) : 0;
      const disputeRate = data.totalOrders > 0 ? parseFloat(((data.disputeCount / data.totalOrders) * 100).toFixed(2)) : 0;

      res.json({
        success: true,
        data: {
          windowDays,
          totalOrders: data.totalOrders,
          settledOrders: data.settledOrders,
          totalVolumePaise: data.totalVolumePaise,
          totalVolumeLovelace: data.totalVolumeLovelace,
          disputeCount: data.disputeCount,
          averageOrderSizePaise,
          averageOrderSizeLovelace,
          escrowCompletionRate,
          disputeRate,
        },
      });
    } catch (err: any) {
      logger.error('Failed to get merchant analytics summary', { detail: err.message });
      res.status(500).json({ success: false, error: 'Internal server error', detail: err.message });
    }
  }
);

// ── GET /api/v1/analytics/merchant/revenue ──────────────────────────────────
router.get(
  '/merchant/revenue',
  requireAuth,
  requireMerchant,
  validate(summaryQuerySchema, 'query'),
  async (req: Request, res: Response): Promise<void> => {
    try {
      const { windowDays } = req.query as unknown as { windowDays: number };
      const merchant = await Merchant.findOne({ userId: req.user._id });
      if (!merchant) {
        res.status(404).json({ success: false, error: 'Merchant profile not found' });
        return;
      }

      const since = new Date(Date.now() - windowDays * 24 * 60 * 60 * 1000);

      const dailyRevenue = await Invoice.aggregate([
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
            volumePaise: { $sum: '$amountPaise' },
            volumeLovelace: { $sum: '$amountLovelace' },
            count: { $sum: 1 },
          },
        },
        { $sort: { _id: 1 } },
      ]);

      const revenueByDay: Record<string, { lovelace: number; paise: number; count: number }> = {};
      for (let i = windowDays - 1; i >= 0; i--) {
        const d = new Date(Date.now() - i * 24 * 60 * 60 * 1000);
        revenueByDay[d.toISOString().slice(0, 10)] = { lovelace: 0, paise: 0, count: 0 };
      }

      for (const row of dailyRevenue) {
        const key = row._id as string;
        if (revenueByDay[key]) {
          revenueByDay[key] = {
            lovelace: row.volumeLovelace as number,
            paise: row.volumePaise as number,
            count: row.count as number,
          };
        }
      }

      res.json({
        success: true,
        data: {
          windowDays,
          timeline: revenueByDay,
        },
      });
    } catch (err: any) {
      logger.error('Failed to get merchant revenue analytics', { detail: err.message });
      res.status(500).json({ success: false, error: 'Internal server error', detail: err.message });
    }
  }
);

// ── GET /api/v1/analytics/merchant/insights ─────────────────────────────────
router.get(
  '/merchant/insights',
  requireAuth,
  requireMerchant,
  validate(summaryQuerySchema, 'query'),
  async (req: Request, res: Response): Promise<void> => {
    try {
      const { windowDays } = req.query as unknown as { windowDays: number };
      const merchant = await Merchant.findOne({ userId: req.user._id });
      if (!merchant) {
        res.status(404).json({ success: false, error: 'Merchant profile not found' });
        return;
      }

      const actorId = req.user.id;
      const requestId = res.locals.requestId;

      const insights = await generateMerchantInsight(merchant._id.toString(), windowDays, actorId, requestId);

      res.json({
        success: true,
        data: insights,
      });
    } catch (err: any) {
      logger.error('Failed to generate AI merchant insights', { detail: err.message });
      res.status(500).json({ success: false, error: 'Internal server error', detail: err.message });
    }
  }
);

const serviceSuggestSchema = z.object({
  description: z.string().min(5, 'Description too short').max(2000),
  category: z.string().min(2, 'Category name too short').max(100),
});

// ── POST /api/v1/analytics/pricing/suggest ──────────────────────────────────
router.post(
  '/pricing/suggest',
  requireAuth,
  requireMerchant,
  validate(serviceSuggestSchema),
  async (req: Request, res: Response): Promise<void> => {
    try {
      const { description, category } = req.body;
      const actorId = req.user.id;
      const requestId = res.locals.requestId;

      const suggestions = await suggestPricingForService(description, category, actorId, requestId);

      res.json({
        success: true,
        data: suggestions,
      });
    } catch (err: any) {
      logger.error('Failed to suggest pricing for service', { detail: err.message });
      res.status(500).json({ success: false, error: 'Internal server error', detail: err.message });
    }
  }
);

// ── POST /api/v1/analytics/invoice/draft ─────────────────────────────────────
router.post(
  '/invoice/draft',
  requireAuth,
  requireMerchant,
  validate(serviceSuggestSchema),
  async (req: Request, res: Response): Promise<void> => {
    try {
      const { description, category } = req.body;
      const actorId = req.user.id;
      const requestId = res.locals.requestId;

      const draft = await generateInvoiceDraft(description, category, actorId, requestId);

      res.json({
        success: true,
        data: draft,
      });
    } catch (err: any) {
      logger.error('Failed to generate AI invoice draft', { detail: err.message });
      res.status(500).json({ success: false, error: 'Internal server error', detail: err.message });
    }
  }
);

export default router;
