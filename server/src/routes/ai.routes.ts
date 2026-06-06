import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { requireAuth, requireMerchant } from '../middleware/auth';
import { validate } from '../middleware/validate';
import { aiRateLimit } from '../middleware/rateLimit';
import {
  generateMilestones,
  summarizeDispute,
  explainEscrowStatus,
  detectTransactionAnomaly,
} from '../services/ai.service';

const router = Router();

const generateMilestonesSchema = z.object({
  description: z.string().min(5, 'Description must be at least 5 characters long').max(1000),
  totalAmountPaise: z.number().int().min(100, 'Minimum ₹1.00'),
});

// POST /api/v1/ai/milestones/generate
router.post(
  '/milestones/generate',
  requireAuth,
  requireMerchant,
  aiRateLimit,
  validate(generateMilestonesSchema),
  async (req: Request, res: Response): Promise<void> => {
    try {
      const { description, totalAmountPaise } = req.body;
      const actorId = req.user.id;
      const requestId = res.locals.requestId;
      const suggestions = await generateMilestones(description, totalAmountPaise, actorId, requestId);
      res.json({ success: true, data: suggestions });
    } catch (err: any) {
      res.status(500).json({ success: false, error: 'Failed to generate milestones', detail: err.message });
    }
  }
);

// POST /api/v1/ai/disputes/:invoiceId/summarize
router.post(
  '/disputes/:invoiceId/summarize',
  requireAuth,
  aiRateLimit,
  async (req: Request, res: Response): Promise<void> => {
    try {
      // Require Admin role
      if (req.user.role !== 'admin') {
        res.status(403).json({ success: false, error: 'Admin access required' });
        return;
      }

      const { invoiceId } = req.params;
      const actorId = req.user.id;
      const requestId = res.locals.requestId;
      const brief = await summarizeDispute(invoiceId, actorId, requestId);
      res.json({ success: true, data: brief });
    } catch (err: any) {
      res.status(500).json({ success: false, error: 'Failed to generate dispute summary', detail: err.message });
    }
  }
);

// GET /api/v1/ai/escrow/:invoiceId/explain
router.get(
  '/escrow/:invoiceId/explain',
  requireAuth,
  aiRateLimit,
  async (req: Request, res: Response): Promise<void> => {
    try {
      const { invoiceId } = req.params;
      const explanation = await explainEscrowStatus(invoiceId);
      res.json({ success: true, data: explanation });
    } catch (err: any) {
      res.status(500).json({ success: false, error: 'Failed to get escrow explanation', detail: err.message });
    }
  }
);

const checkAnomalySchema = z.object({
  merchantAddress: z.string().regex(/^addr(_test)?1[a-z0-9]+$/),
  customerAddress: z.string().regex(/^addr(_test)?1[a-z0-9]+$/),
  amountLovelace: z.number().int().positive(),
});

// POST /api/v1/ai/fraud/check
router.post(
  '/fraud/check',
  requireAuth,
  aiRateLimit,
  validate(checkAnomalySchema),
  async (req: Request, res: Response): Promise<void> => {
    try {
      const { merchantAddress, customerAddress, amountLovelace } = req.body;
      const actorId = req.user.id;
      const requestId = res.locals.requestId;
      const report = await detectTransactionAnomaly(merchantAddress, customerAddress, amountLovelace, actorId, requestId);
      res.json({ success: true, data: report });
    } catch (err: any) {
      res.status(500).json({ success: false, error: 'Failed to check anomalies', detail: err.message });
    }
  }
);

export default router;
