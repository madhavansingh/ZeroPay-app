import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { requireAuth, requireMerchant } from '../middleware/auth';
import { validate } from '../middleware/validate';
import { aiRateLimit } from '../middleware/rateLimit';
import { ProjectPlan } from '../models/ProjectPlan';
import { Merchant } from '../models/Merchant';
import { generateProjectPlan } from '../services/ai.service';
import { createInvoice } from '../services/invoice.service';

const router = Router();

const createPlanSchema = z.object({
  requirements: z.string().min(5, 'Requirements description is too short').max(2000),
  totalAmountPaise: z.number().int().min(100, 'Minimum budget of ₹1.00 required'),
  customerId: z.string().optional(),
});

function generateLogicalPlanId(): string {
  const date = new Date().toISOString().slice(0, 10).replace(/-/g, '');
  const suffix = Math.random().toString(36).substring(2, 8).toUpperCase();
  return `PLAN-${date}-${suffix}`;
}

// POST /api/v1/projects/plan
router.post(
  '/plan',
  requireAuth,
  requireMerchant,
  aiRateLimit,
  validate(createPlanSchema),
  async (req: Request, res: Response): Promise<void> => {
    try {
      const { requirements, totalAmountPaise, customerId } = req.body;
      const merchant = await Merchant.findOne({ userId: req.user._id });
      if (!merchant) {
        res.status(400).json({ success: false, error: 'Merchant profile not found' });
        return;
      }

      const generatedPlan = await generateProjectPlan(
        requirements,
        totalAmountPaise,
        merchant._id.toString(),
        customerId,
        req.user.id,
        res.locals.requestId
      );

      const planId = generateLogicalPlanId();
      const projectPlan = await ProjectPlan.create({
        planId,
        version: 1,
        merchantId: merchant._id,
        customerId: customerId || undefined,
        requirements,
        projectSummary: generatedPlan.projectSummary,
        scope: generatedPlan.scope,
        milestones: generatedPlan.milestones,
        tasks: generatedPlan.tasks,
        requirementsBreakdown: generatedPlan.requirementsBreakdown,
        timeline: generatedPlan.timeline,
        acceptanceCriteria: generatedPlan.acceptanceCriteria,
        riskFactors: generatedPlan.riskFactors,
        planningConfidence: generatedPlan.planningConfidence,
        assumptions: generatedPlan.assumptions,
        unknowns: generatedPlan.unknowns,
        budgetAllocation: generatedPlan.budgetAllocation,
        escrowPlan: generatedPlan.escrowPlan,
        status: 'AI Generated',
      });

      res.status(201).json({ success: true, data: projectPlan });
    } catch (err: any) {
      res.status(500).json({ success: false, error: 'Failed to generate project plan', detail: err.message });
    }
  }
);

// GET /api/v1/projects/plan/:planId
router.get(
  '/plan/:planId',
  requireAuth,
  async (req: Request, res: Response): Promise<void> => {
    try {
      const { planId } = req.params;
      const plan = await ProjectPlan.findOne({ planId }).sort({ version: -1 });
      if (!plan) {
        res.status(404).json({ success: false, error: 'Project plan not found' });
        return;
      }
      res.json({ success: true, data: plan });
    } catch (err: any) {
      res.status(500).json({ success: false, error: 'Failed to retrieve project plan', detail: err.message });
    }
  }
);

// GET /api/v1/projects/plan/:planId/versions
router.get(
  '/plan/:planId/versions',
  requireAuth,
  async (req: Request, res: Response): Promise<void> => {
    try {
      const { planId } = req.params;
      const plans = await ProjectPlan.find({ planId }).sort({ version: -1 });
      res.json({ success: true, data: plans });
    } catch (err: any) {
      res.status(500).json({ success: false, error: 'Failed to retrieve plan versions', detail: err.message });
    }
  }
);

// GET /api/v1/projects/plan/:planId/version/:version
router.get(
  '/plan/:planId/version/:version',
  requireAuth,
  async (req: Request, res: Response): Promise<void> => {
    try {
      const { planId, version } = req.params;
      const plan = await ProjectPlan.findOne({ planId, version: parseInt(version, 10) });
      if (!plan) {
        res.status(404).json({ success: false, error: 'Plan version not found' });
        return;
      }
      res.json({ success: true, data: plan });
    } catch (err: any) {
      res.status(500).json({ success: false, error: 'Failed to retrieve plan version', detail: err.message });
    }
  }
);

// PUT /api/v1/projects/plan/:planId
router.put(
  '/plan/:planId',
  requireAuth,
  requireMerchant,
  async (req: Request, res: Response): Promise<void> => {
    try {
      const { planId } = req.params;
      const latestPlan = await ProjectPlan.findOne({ planId }).sort({ version: -1 });
      if (!latestPlan) {
        res.status(404).json({ success: false, error: 'Project plan not found' });
        return;
      }

      if (['Approved', 'Invoice Created', 'Escrow Created'].includes(latestPlan.status)) {
        res.status(400).json({ success: false, error: 'Cannot edit an approved or locked project plan' });
        return;
      }

      // Update plan parameters
      Object.assign(latestPlan, req.body, { status: 'User Edited' });
      await latestPlan.save();

      res.json({ success: true, data: latestPlan });
    } catch (err: any) {
      res.status(500).json({ success: false, error: 'Failed to update project plan', detail: err.message });
    }
  }
);

const regenerateSchema = z.object({
  requirements: z.string().min(5).max(2000).optional(),
  totalAmountPaise: z.number().int().min(100).optional(),
  customerId: z.string().optional(),
});

// POST /api/v1/projects/plan/:planId/regenerate
router.post(
  '/plan/:planId/regenerate',
  requireAuth,
  requireMerchant,
  aiRateLimit,
  validate(regenerateSchema),
  async (req: Request, res: Response): Promise<void> => {
    try {
      const { planId } = req.params;
      const { requirements, totalAmountPaise, customerId } = req.body;

      const latestPlan = await ProjectPlan.findOne({ planId }).sort({ version: -1 });
      if (!latestPlan) {
        res.status(404).json({ success: false, error: 'Project plan not found' });
        return;
      }

      if (['Approved', 'Invoice Created', 'Escrow Created'].includes(latestPlan.status)) {
        res.status(400).json({ success: false, error: 'Cannot regenerate an approved or locked project plan' });
        return;
      }

      const activeRequirements = requirements || latestPlan.requirements;
      const activeTotalPaise = totalAmountPaise || latestPlan.milestones.reduce((sum, m) => sum + m.amountPaise, 0);

      const generatedPlan = await generateProjectPlan(
        activeRequirements,
        activeTotalPaise,
        latestPlan.merchantId.toString(),
        customerId || latestPlan.customerId?.toString(),
        req.user.id,
        res.locals.requestId
      );

      const projectPlan = await ProjectPlan.create({
        planId,
        version: latestPlan.version + 1,
        merchantId: latestPlan.merchantId,
        customerId: customerId || latestPlan.customerId,
        requirements: activeRequirements,
        projectSummary: generatedPlan.projectSummary,
        scope: generatedPlan.scope,
        milestones: generatedPlan.milestones,
        tasks: generatedPlan.tasks,
        requirementsBreakdown: generatedPlan.requirementsBreakdown,
        timeline: generatedPlan.timeline,
        acceptanceCriteria: generatedPlan.acceptanceCriteria,
        riskFactors: generatedPlan.riskFactors,
        planningConfidence: generatedPlan.planningConfidence,
        assumptions: generatedPlan.assumptions,
        unknowns: generatedPlan.unknowns,
        budgetAllocation: generatedPlan.budgetAllocation,
        escrowPlan: generatedPlan.escrowPlan,
        status: 'AI Generated',
      });

      res.status(201).json({ success: true, data: projectPlan });
    } catch (err: any) {
      res.status(500).json({ success: false, error: 'Failed to regenerate project plan', detail: err.message });
    }
  }
);

const approveSchema = z.object({
  network: z.enum(['cardano', 'base']).optional(),
});

// POST /api/v1/projects/plan/:planId/approve
router.post(
  '/plan/:planId/approve',
  requireAuth,
  requireMerchant,
  validate(approveSchema),
  async (req: Request, res: Response): Promise<void> => {
    try {
      const { planId } = req.params;
      const { network } = req.body;

      const latestPlan = await ProjectPlan.findOne({ planId }).sort({ version: -1 });
      if (!latestPlan) {
        res.status(404).json({ success: false, error: 'Project plan not found' });
        return;
      }

      if (latestPlan.invoiceId) {
        res.status(400).json({ success: false, error: 'Plan is already approved and invoice has been created' });
        return;
      }

      // 1. Transition plan status to Approved
      latestPlan.status = 'Approved';
      await latestPlan.save();

      const totalAmountPaise = latestPlan.milestones.reduce((sum, m) => sum + m.amountPaise, 0);

      // 2. Create invoice and link projectPlanId
      const invoice = await createInvoice({
        merchantMongoId: latestPlan.merchantId.toString(),
        amountPaise: totalAmountPaise,
        description: latestPlan.projectSummary.substring(0, 100),
        customerId: latestPlan.customerId?.toString(),
        projectPlanId: latestPlan.planId,
        milestones: latestPlan.milestones.map((m) => ({
          milestoneId: m.milestoneId,
          title: m.title,
          description: m.description,
          amountPaise: m.amountPaise,
        })),
        network: network || 'cardano',
      });

      // 3. Transition to Invoice Created
      latestPlan.status = 'Invoice Created';
      latestPlan.invoiceId = invoice.invoiceId;
      await latestPlan.save();

      res.json({
        success: true,
        data: {
          projectPlan: latestPlan,
          invoice: {
            invoiceId: invoice.invoiceId,
            amountPaise: invoice.amountPaise,
            amountLovelace: invoice.amountLovelace,
            status: invoice.status,
            expiresAt: invoice.expiresAt,
            paymentAddress: invoice.paymentAddress,
            network: invoice.network,
          },
        },
      });
    } catch (err: any) {
      res.status(500).json({ success: false, error: 'Failed to approve plan and create invoice', detail: err.message });
    }
  }
);

export default router;
