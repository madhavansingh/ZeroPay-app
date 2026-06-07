import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { requireAuth } from '../middleware/auth';
import { validate } from '../middleware/validate';
import { githubAuditService } from '../services/githubAudit.service';
import { GitHubAudit } from '../models/GitHubAudit';
import { GitHubAuditSnapshot } from '../models/GitHubAuditSnapshot';
import { ProjectPlan } from '../models/ProjectPlan';
import { Merchant } from '../models/Merchant';
import { logger } from '../config/logger';

const router = Router();

const connectRepoSchema = z.object({
  projectPlanId: z.string().min(5),
  repositoryUrl: z.string().url(),
  branch: z.string().optional().default('main'),
});

const triggerAuditSchema = z.object({
  projectPlanId: z.string().min(5),
  milestoneId: z.string().min(3),
});

// POST /api/v1/github/connect
router.post(
  '/connect',
  requireAuth,
  validate(connectRepoSchema),
  async (req: Request, res: Response): Promise<void> => {
    try {
      const { projectPlanId, repositoryUrl, branch } = req.body;
      const plan = await ProjectPlan.findOne({ planId: projectPlanId });
      if (!plan) {
        res.status(404).json({ success: false, error: 'Project plan not found' });
        return;
      }
      const merchant = await Merchant.findOne({ userId: req.user._id });
      if (!merchant || plan.merchantId.toString() !== merchant._id.toString()) {
        res.status(403).json({ success: false, error: 'Access denied: You do not own this project plan.' });
        return;
      }

      const result = await githubAuditService.connectRepository(projectPlanId, repositoryUrl, branch);
      res.status(200).json({ success: true, data: result });
    } catch (err: any) {
      res.status(500).json({ success: false, error: err.message });
    }
  }
);

// POST /api/v1/github/audit
router.post(
  '/audit',
  requireAuth,
  validate(triggerAuditSchema),
  async (req: Request, res: Response): Promise<void> => {
    try {
      const { projectPlanId, milestoneId } = req.body;
      const plan = await ProjectPlan.findOne({ planId: projectPlanId });
      if (!plan) {
        res.status(404).json({ success: false, error: 'Project plan not found' });
        return;
      }
      const merchant = await Merchant.findOne({ userId: req.user._id });
      if (!merchant || plan.merchantId.toString() !== merchant._id.toString()) {
        res.status(403).json({ success: false, error: 'Access denied: You do not own this project plan.' });
        return;
      }

      const result = await githubAuditService.runMilestoneAudit(
        projectPlanId,
        milestoneId,
        req.user.id || 'system',
        res.locals.requestId
      );
      res.status(201).json({ success: true, data: result });
    } catch (err: any) {
      res.status(500).json({ success: false, error: err.message });
    }
  }
);

// GET /api/v1/github/audit/:auditId
router.get(
  '/audit/:auditId',
  requireAuth,
  async (req: Request, res: Response): Promise<void> => {
    try {
      const audit = await GitHubAudit.findOne({ auditId: req.params.auditId });
      if (!audit) {
        res.status(404).json({ success: false, error: 'Audit log not found' });
        return;
      }
      const snapshot = await GitHubAuditSnapshot.findOne({ auditId: req.params.auditId });
      res.status(200).json({ success: true, data: { audit, snapshot } });
    } catch (err: any) {
      res.status(500).json({ success: false, error: err.message });
    }
  }
);

// GET /api/v1/github/audit/project/:projectPlanId
router.get(
  '/audit/project/:projectPlanId',
  requireAuth,
  async (req: Request, res: Response): Promise<void> => {
    try {
      const audits = await GitHubAudit.find({ projectPlanId: req.params.projectPlanId }).sort({ createdAt: -1 });
      res.status(200).json({ success: true, data: audits });
    } catch (err: any) {
      res.status(500).json({ success: false, error: err.message });
    }
  }
);

// POST /api/v1/github/audit/:auditId/reverify
router.post(
  '/audit/:auditId/reverify',
  requireAuth,
  async (req: Request, res: Response): Promise<void> => {
    try {
      const audit = await GitHubAudit.findOne({ auditId: req.params.auditId });
      if (!audit) {
        res.status(404).json({ success: false, error: 'Audit log not found' });
        return;
      }

      const plan = await ProjectPlan.findOne({ planId: audit.projectPlanId });
      if (!plan) {
        res.status(404).json({ success: false, error: 'Project plan not found' });
        return;
      }
      const merchant = await Merchant.findOne({ userId: req.user._id });
      if (!merchant || plan.merchantId.toString() !== merchant._id.toString()) {
        res.status(403).json({ success: false, error: 'Access denied: You do not own this project plan.' });
        return;
      }

      const result = await githubAuditService.runMilestoneAudit(
        audit.projectPlanId,
        audit.milestoneId,
        req.user.id || 'system',
        res.locals.requestId
      );
      res.status(201).json({ success: true, data: result });
    } catch (err: any) {
      res.status(500).json({ success: false, error: err.message });
    }
  }
);

// POST /api/v1/github/audit/:auditId/request-fixes
router.post(
  '/audit/:auditId/request-fixes',
  requireAuth,
  validate(z.object({ feedback: z.string() })),
  async (req: Request, res: Response): Promise<void> => {
    try {
      const audit = await GitHubAudit.findOne({ auditId: req.params.auditId });
      if (!audit) {
        res.status(404).json({ success: false, error: 'Audit log not found' });
        return;
      }

      const plan = await ProjectPlan.findOne({ planId: audit.projectPlanId });
      if (!plan) {
        res.status(404).json({ success: false, error: 'Project plan not found' });
        return;
      }
      const merchant = await Merchant.findOne({ userId: req.user._id });
      if (!merchant || plan.merchantId.toString() !== merchant._id.toString()) {
        res.status(403).json({ success: false, error: 'Access denied: You do not own this project plan.' });
        return;
      }

      audit.findings += `\n\n[Fixes Requested by Buyer]: ${req.body.feedback}`;
      audit.releaseRecommendation = 'RECOMMEND_MAJOR_REWORK';
      await audit.save();

      res.status(200).json({ success: true, data: audit });
    } catch (err: any) {
      res.status(500).json({ success: false, error: err.message });
    }
  }
);

// POST /api/v1/github/audit/:auditId/release-recommendation
router.post(
  '/audit/:auditId/release-recommendation',
  requireAuth,
  async (req: Request, res: Response): Promise<void> => {
    try {
      const audit = await GitHubAudit.findOne({ auditId: req.params.auditId });
      if (!audit) {
        res.status(404).json({ success: false, error: 'Audit log not found' });
        return;
      }

      res.status(200).json({
        success: true,
        data: {
          auditId: audit.auditId,
          releaseRecommendation: audit.releaseRecommendation,
          releaseConfidenceScore: audit.releaseConfidenceScore,
          auditStatus: audit.auditStatus,
          verdictExplanation: audit.findings,
        },
      });
    } catch (err: any) {
      res.status(500).json({ success: false, error: err.message });
    }
  }
);

export default router;
