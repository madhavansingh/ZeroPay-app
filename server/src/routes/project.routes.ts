import { Router, Request, Response } from 'express';
import { z } from 'zod';
import mongoose from 'mongoose';
import fs from 'fs';
import path from 'path';
import { requireAuth, requireMerchant } from '../middleware/auth';
import { validate } from '../middleware/validate';
import { aiRateLimit } from '../middleware/rateLimit';
import { ProjectPlan } from '../models/ProjectPlan';
import { Merchant } from '../models/Merchant';
import { generateProjectPlanWithNemotron } from '../services/nemotron.service';
import { createInvoice } from '../services/invoice.service';
import { env } from '../config/env';

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

function mapNemotronPlanToDbFields(
  generatedPlan: any,
  totalAmountPaise: number
) {
  const date = new Date().toISOString().slice(0, 10).replace(/-/g, '');

  const classifyGithubAuditRequirements = (reqs: string[]) => {
    const requiredFiles: string[] = [];
    const requiredFeatures: string[] = [];
    const requiredTests: string[] = [];
    const requiredDocumentation: string[] = [];

    for (const req of reqs) {
      const lower = req.toLowerCase();
      if (lower.includes('test') || lower.includes('spec') || lower.includes('assert')) {
        requiredTests.push(req);
      } else if (lower.includes('doc') || lower.includes('wiki') || lower.includes('guide') || lower.endsWith('.md')) {
        requiredDocumentation.push(req);
      } else if (
        lower.includes('.') || 
        lower.includes('/') || 
        /\.(ts|js|dart|go|rs|py|json|yaml|yml|sh|css|html|c|cpp|h|java|kt|swift|rb)$/.test(lower)
      ) {
        requiredFiles.push(req);
      } else {
        requiredFeatures.push(req);
      }
    }

    return { requiredFiles, requiredFeatures, requiredTests, requiredDocumentation };
  };

  let sumMilestoneBudget = 0;
  const dbMilestones = generatedPlan.milestones.map((m: any, index: number) => {
    const msId = `MS-${date}-${Math.random().toString(36).substring(2, 8).toUpperCase()}`;
    sumMilestoneBudget += m.budgetAllocation;
    return {
      milestoneId: msId,
      title: m.title,
      description: m.description,
      amountPaise: m.budgetAllocation,
      status: 'pending' as const,
      githubAuditRequirements: classifyGithubAuditRequirements(m.githubAuditRequirements || []),
      _tempTitle: m.title,
    };
  });

  if (sumMilestoneBudget !== totalAmountPaise && dbMilestones.length > 0) {
    const diff = totalAmountPaise - sumMilestoneBudget;
    dbMilestones[dbMilestones.length - 1].amountPaise += diff;
  }

  const dbTasks = generatedPlan.tasks.map((t: any) => {
    const tskId = `TSK-${date}-${Math.random().toString(36).substring(2, 8).toUpperCase()}`;
    return {
      taskId: tskId,
      title: t.title,
      description: t.description,
      estimatedHours: t.estimatedHours,
      priority: t.priority,
      acceptanceCriteria: t.acceptanceCriteria || [],
      githubAuditRequirements: classifyGithubAuditRequirements(t.githubAuditRequirements || []),
      _tempTitle: t.title,
    };
  });

  const dbRequirementTrace = (generatedPlan.functionalRequirements || []).map((req: string, index: number) => {
    const reqId = `REQ-${String(index + 1).padStart(3, '0')}`;
    const words = req.toLowerCase().split(/\W+/).filter(w => w.length > 3);
    let linkedMilestones = dbMilestones.filter((m: any) => {
      const titleLower = m._tempTitle.toLowerCase();
      const descLower = m.description.toLowerCase();
      return words.some((word) => titleLower.includes(word) || descLower.includes(word));
    }).map((m: any) => m.milestoneId);

    if (linkedMilestones.length === 0 && dbMilestones.length > 0) {
      linkedMilestones = [dbMilestones[0].milestoneId];
    }

    let linkedTasks = dbTasks.filter((t: any) => {
      const titleLower = t._tempTitle.toLowerCase();
      const descLower = t.description.toLowerCase();
      return words.some((word) => titleLower.includes(word) || descLower.includes(word));
    }).map((t: any) => t.taskId);

    if (linkedTasks.length === 0 && dbTasks.length > 0) {
      linkedTasks = [dbTasks[0].taskId];
    }

    const requiredFiles = new Set<string>();
    const requiredFeatures = new Set<string>();
    const requiredTests = new Set<string>();
    const requiredDocumentation = new Set<string>();

    linkedTasks.forEach((tId: string) => {
      const task = dbTasks.find((tk: any) => tk.taskId === tId);
      if (task && task.githubAuditRequirements) {
        (task.githubAuditRequirements.requiredFiles || []).forEach((f: string) => requiredFiles.add(f));
        (task.githubAuditRequirements.requiredFeatures || []).forEach((f: string) => requiredFeatures.add(f));
        (task.githubAuditRequirements.requiredTests || []).forEach((f: string) => requiredTests.add(f));
        (task.githubAuditRequirements.requiredDocumentation || []).forEach((f: string) => requiredDocumentation.add(f));
      }
    });

    return {
      requirementId: reqId,
      requirement: req,
      milestoneIds: linkedMilestones,
      taskIds: linkedTasks,
      githubAuditRequirements: {
        requiredFiles: Array.from(requiredFiles),
        requiredFeatures: Array.from(requiredFeatures),
        requiredTests: Array.from(requiredTests),
        requiredDocumentation: Array.from(requiredDocumentation),
      },
    };
  });

  const dbRequirementsBreakdown = dbRequirementTrace.map((r: any) => ({
    requirement: r.requirement,
    linkedMilestones: r.milestoneIds,
    linkedTasks: r.taskIds,
  }));

  // Clean up temp titles
  dbMilestones.forEach((m: any) => delete m._tempTitle);
  dbTasks.forEach((t: any) => delete t._tempTitle);

  const riskFactors = (generatedPlan.riskAnalysis || []).map(
    (r: any) => `[${r.severity.toUpperCase()}] ${r.description} (Mitigation: ${r.mitigation})`
  );

  const budgetAllocation = generatedPlan.milestones.map((m: any) => ({
    category: m.title,
    percentage: m.percentage,
    amountPaise: m.budgetAllocation,
  }));

  const sumBudget = budgetAllocation.reduce((sum: number, b: any) => sum + b.amountPaise, 0);
  if (sumBudget !== totalAmountPaise && budgetAllocation.length > 0) {
    const diff = totalAmountPaise - sumBudget;
    budgetAllocation[budgetAllocation.length - 1].amountPaise += diff;
  }
  const sumPercent = budgetAllocation.reduce((sum: number, b: any) => sum + b.percentage, 0);
  if (sumPercent !== 100 && budgetAllocation.length > 0) {
    const diff = 100 - sumPercent;
    budgetAllocation[budgetAllocation.length - 1].percentage += diff;
  }

  const scope = [
    `Product Vision: ${generatedPlan.productVision}`,
    `System Architecture: ${generatedPlan.systemArchitecture}`,
    `Database Design: ${generatedPlan.databaseDesign}`,
    `API Design: ${generatedPlan.apiDesign}`,
    `Deployment Strategy: ${generatedPlan.deploymentStrategy}`,
    `Testing Strategy: ${generatedPlan.testingStrategy}`
  ].join('\n\n');

  return {
    projectSummary: generatedPlan.executiveSummary,
    scope,
    milestones: dbMilestones,
    tasks: dbTasks,
    requirementsBreakdown: dbRequirementsBreakdown,
    requirementTrace: dbRequirementTrace,
    timeline: {
      optimisticDays: generatedPlan.timelineEstimates?.optimisticDays || 1,
      realisticDays: generatedPlan.timelineEstimates?.realisticDays || 2,
      conservativeDays: generatedPlan.timelineEstimates?.conservativeDays || 3,
      summary: generatedPlan.timelineEstimates?.summary || '',
    },
    acceptanceCriteria: generatedPlan.acceptanceCriteria || [],
    riskFactors,
    budgetAllocation,
    planningConfidence: 100,
    assumptions: [
      'Standard hardware and runtime environments.',
      'Merchant provides GitHub repository access for automated auditing.',
    ],
    unknowns: [
      'Third-party API rate limits and availability.',
      'Specific vendor approval turnaround times.',
    ],
    escrowPlan: {
      structure: 'Milestone-based progressive release escrow structure.',
      rationale: 'Funds are released progressively as milestones are successfully completed and verified by GitHub Audit.'
    },
  };
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

      const generatedPlan = await generateProjectPlanWithNemotron(
        requirements,
        totalAmountPaise
      );

      const planFields = mapNemotronPlanToDbFields(generatedPlan, totalAmountPaise);

      const planId = generateLogicalPlanId();
      const projectPlan = await ProjectPlan.create({
        planId,
        version: 1,
        merchantId: merchant._id,
        customerId: customerId || undefined,
        requirements,
        ...planFields,
        provider: 'nemotron',
        model: env.PLANNER_MODEL,
        rawAiOutput: generatedPlan,
        generatedAt: new Date(),
        status: 'AI Generated',
      });

      res.status(201).json({ success: true, data: projectPlan });
    } catch (err: any) {
      res.status(500).json({ success: false, error: 'Failed to generate project plan', detail: err.message });
    }
  }
);

// Zod schemas for validating n8n project plan imports
const importGithubAuditReqsSchema = z.object({
  requiredFiles: z.array(z.string()).default([]),
  requiredFeatures: z.array(z.string()).default([]),
  requiredTests: z.array(z.string()).default([]),
  requiredDocumentation: z.array(z.string()).default([]),
});

const importMilestoneSchema = z.object({
  milestoneId: z.string().min(3),
  title: z.string().min(3),
  description: z.string().optional().default(''),
  amountPaise: z.number().int().positive(),
  status: z.enum(['pending', 'released', 'disputed']).optional().default('pending'),
  githubAuditRequirements: importGithubAuditReqsSchema.optional().default({}),
});

const importTaskSchema = z.object({
  taskId: z.string().min(3),
  title: z.string().min(3),
  description: z.string().optional().default(''),
  estimatedHours: z.number().int().positive(),
  priority: z.enum(['low', 'medium', 'high']).optional().default('medium'),
  acceptanceCriteria: z.array(z.string()).default([]),
  githubAuditRequirements: importGithubAuditReqsSchema.optional().default({}),
});

const importRequirementsBreakdownSchema = z.object({
  requirement: z.string().min(3),
  linkedMilestones: z.array(z.string()).default([]),
  linkedTasks: z.array(z.string()).default([]),
});

const importRequirementTraceSchema = z.object({
  requirementId: z.string().min(3),
  requirement: z.string().min(3),
  milestoneIds: z.array(z.string()).default([]),
  taskIds: z.array(z.string()).default([]),
  githubAuditRequirements: importGithubAuditReqsSchema.optional().default({}),
});

const importBudgetAllocationSchema = z.object({
  category: z.string().min(2),
  percentage: z.number().min(0).max(100),
  amountPaise: z.number().int().positive(),
});

const importPlanSchema = z.object({
  projectPlan: z.object({
    planId: z.string().min(5),
    version: z.number().int().positive().optional().default(1),
    customerId: z.string().optional(),
    requirements: z.string().min(5).optional(),
    projectDescription: z.string().min(5).optional(),
    projectSummary: z.string().min(5).optional().default(''),
    scope: z.string().min(5).optional(),
    projectScope: z.string().min(5).optional(),
    milestones: z.array(importMilestoneSchema).min(1),
    tasks: z.array(importTaskSchema).default([]),
    requirementsBreakdown: z.array(importRequirementsBreakdownSchema).default([]),
    requirementTraceability: z.array(importRequirementTraceSchema).optional(),
    requirementTrace: z.array(importRequirementTraceSchema).optional(),
    timeline: z.object({
      optimisticDays: z.number().int().positive().optional(),
      optimistic: z.number().int().positive().optional(),
      realisticDays: z.number().int().positive().optional(),
      realistic: z.number().int().positive().optional(),
      conservativeDays: z.number().int().positive().optional(),
      conservative: z.number().int().positive().optional(),
      summary: z.string().optional().default(''),
    }),
    acceptanceCriteria: z.array(z.string()).default([]),
    riskFactors: z.union([
      z.array(z.string()),
      z.object({
        riskFactors: z.array(z.any()),
        overallRiskScore: z.number().optional(),
        recommendedContingencyBudget: z.number().optional(),
      }),
    ]).optional(),
    budgetAllocation: z.union([
      z.array(importBudgetAllocationSchema),
      z.object({
        totalBudget: z.number().optional(),
        milestoneAllocations: z.array(z.any()),
        contingencyRecommended: z.number().optional(),
      }),
    ]).optional(),
    escrowStructure: z.array(z.any()).optional(),
    escrowPlan: z.object({
      structure: z.string().optional(),
      rationale: z.string().optional(),
    }).optional(),
    githubAuditRequirements: z.any().optional(),
    planningConfidence: z.number().int().min(0).max(100).optional().default(100),
    assumptions: z.array(z.string()).default([]),
    unknowns: z.array(z.string()).default([]),
  }),
  metadata: z.object({
    workflowVersion: z.string(),
    executionId: z.string(),
    generatedAt: z.string(),
  }),
  telemetry: z.object({
    durationMs: z.number().int().nonnegative(),
    tokensUsed: z.number().int().optional(),
    generatedMilestones: z.number().int().nonnegative(),
    generatedTasks: z.number().int().nonnegative(),
    generatedRequirements: z.number().int().nonnegative(),
    complexityScore: z.number().int().nonnegative(),
    riskScore: z.number().int().nonnegative(),
    planningConfidence: z.number().int().nonnegative(),
  }),
});

// POST /api/v1/projects/plan/import
router.post(
  '/plan/import',
  requireAuth,
  requireMerchant,
  validate(importPlanSchema),
  async (req: Request, res: Response): Promise<void> => {
    try {
      const { projectPlan, metadata, telemetry } = req.body;

      // 1. Verify workflow version against manifest
      let manifestPath = path.resolve(process.cwd(), '../shared/workflows/project-planner-manifest.json');
      if (!fs.existsSync(manifestPath)) {
        manifestPath = path.resolve(process.cwd(), 'shared/workflows/project-planner-manifest.json');
      }

      if (!fs.existsSync(manifestPath)) {
        res.status(500).json({ success: false, error: 'Workflow manifest configuration not found on server.' });
        return;
      }

      const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
      const allowedVersions: string[] = manifest.allowedWorkflowVersions || [];
      if (!allowedVersions.includes(metadata.workflowVersion)) {
        res.status(400).json({
          success: false,
          error: `Rejected import: unknown or unauthorized workflow version '${metadata.workflowVersion}'.`,
        });
        return;
      }

      // 2. Fetch merchant
      const merchant = await Merchant.findOne({ userId: req.user._id });
      if (!merchant) {
        res.status(400).json({ success: false, error: 'Merchant profile not found' });
        return;
      }

      // 3. Map complex n8n structures to match backend mongoose schema requirements
      const totalBudget = projectPlan.budgetAllocation?.totalBudget || telemetry.totalBudget || 0;
      
      const budgetAllocation = Array.isArray(projectPlan.budgetAllocation)
        ? projectPlan.budgetAllocation.map((b: any) => ({
            category: b.category,
            percentage: b.percentage,
            amountPaise: b.amountPaise || Math.round(totalBudget * (b.percentage / 100)),
          }))
        : Array.isArray(projectPlan.budgetAllocation?.milestoneAllocations)
          ? projectPlan.budgetAllocation.milestoneAllocations.map((m: any) => ({
              category: m.milestoneName || m.title || 'Milestone Allocation',
              percentage: totalBudget > 0 ? Math.round(((m.escrowAmount || 0) / totalBudget) * 100) : 0,
              amountPaise: m.escrowAmount || 0,
            }))
          : [];

      const mappedRiskFactors = Array.isArray(projectPlan.riskFactors)
        ? projectPlan.riskFactors.map((r: any) => typeof r === 'string' ? r : `${r.category || 'Overall'} Risk: ${r.description || ''} (Mitigation: ${r.mitigation || ''})`)
        : Array.isArray(projectPlan.riskFactors?.riskFactors)
          ? projectPlan.riskFactors.riskFactors.map((r: any) => `${r.category || 'Overall'} Risk: ${r.description || ''} (Mitigation: ${r.mitigation || ''})`)
          : [];

      const auditCheckpoints = projectPlan.githubAuditRequirements?.auditCheckpoints || [];
      const milestones = (projectPlan.milestones || []).map((m: any, index: number) => {
        const audit = auditCheckpoints.find((c: any) => c.milestoneId === m.milestoneId);
        return {
          milestoneId: m.milestoneId || `MS-${Date.now()}-${String(index + 1).padStart(3, '0')}`,
          title: m.title || m.name,
          description: m.description || (Array.isArray(m.deliverables) ? m.deliverables.join(', ') : m.deliverables || ''),
          amountPaise: m.amountPaise || m.escrowAmount || 0,
          status: m.status || 'pending',
          githubAuditRequirements: {
            requiredFiles: audit?.requiredFiles || [],
            requiredFeatures: audit?.requiredFeatures || [],
            requiredTests: audit?.requiredTests || [],
            requiredDocumentation: audit?.requiredDocumentation || [],
          },
        };
      });

      const tasks = (projectPlan.tasks || []).map((t: any) => ({
        taskId: t.taskId || `TSK-${Date.now()}-${Math.random().toString(36).substring(2, 6).toUpperCase()}`,
        title: t.name || t.title,
        description: t.description || '',
        estimatedHours: t.estimatedHours || 0,
        priority: ['low', 'medium', 'high'].includes(t.priority) ? t.priority : 'medium',
        acceptanceCriteria: Array.isArray(t.acceptanceCriteria) ? t.acceptanceCriteria : [],
        githubAuditRequirements: {
          requiredFiles: t.githubAuditRequirements?.requiredFiles || [],
          requiredFeatures: t.githubAuditRequirements?.requiredFeatures || [],
          requiredTests: t.githubAuditRequirements?.requiredTests || [],
          requiredDocumentation: t.githubAuditRequirements?.requiredDocumentation || [],
        },
      }));

      const rawTrace = projectPlan.requirementTraceability || projectPlan.requirementTrace || [];
      const requirementTrace = rawTrace.map((r: any) => ({
        requirementId: r.requirementId,
        requirement: r.requirement,
        milestoneIds: r.milestoneIds || [],
        taskIds: r.taskIds || [],
        githubAuditRequirements: {
          requiredFiles: r.githubAuditRequirements?.requiredFiles || [],
          requiredFeatures: r.githubAuditRequirements?.requiredFeatures || [],
          requiredTests: r.githubAuditRequirements?.requiredTests || [],
          requiredDocumentation: r.githubAuditRequirements?.requiredDocumentation || [],
        },
      }));

      const requirementsBreakdown = requirementTrace.map((r: any) => ({
        requirement: r.requirement,
        linkedMilestones: r.milestoneIds,
        linkedTasks: r.taskIds,
      }));

      const escrowPlan = projectPlan.escrowPlan || {
        structure: Array.isArray(projectPlan.escrowStructure)
          ? projectPlan.escrowStructure.map((e: any) => `${e.milestoneName || e.title || 'Milestone'}: ${e.escrowAmount || 0} Paise (${Array.isArray(e.releaseConditions) ? e.releaseConditions.join(', ') : e.releaseConditions || ''})`).join('\n')
          : typeof projectPlan.escrowPlan?.structure === 'string'
            ? projectPlan.escrowPlan.structure
            : 'Milestone-based progressive release escrow structure.',
        rationale: projectPlan.escrowPlan?.rationale || 'Budget allocated progressively based on milestone complexity and deliverables.',
      };

      const projectPlanDoc = await ProjectPlan.create({
        planId: projectPlan.planId,
        version: projectPlan.version || 1,
        merchantId: merchant._id,
        customerId: projectPlan.customerId ? new mongoose.Types.ObjectId(projectPlan.customerId) : undefined,
        requirements: projectPlan.requirements || projectPlan.projectDescription || '',
        projectSummary: projectPlan.projectSummary || '',
        scope: projectPlan.scope || projectPlan.projectScope || '',
        milestones,
        tasks,
        requirementsBreakdown,
        requirementTrace,
        timeline: {
          optimisticDays: projectPlan.timeline?.optimisticDays || projectPlan.timeline?.optimistic || 1,
          realisticDays: projectPlan.timeline?.realisticDays || projectPlan.timeline?.realistic || 2,
          conservativeDays: projectPlan.timeline?.conservativeDays || projectPlan.timeline?.conservative || 3,
          summary: projectPlan.timeline?.summary || '',
        },
        acceptanceCriteria: Array.isArray(projectPlan.acceptanceCriteria) ? projectPlan.acceptanceCriteria : [],
        riskFactors: mappedRiskFactors,
        planningConfidence: projectPlan.planningConfidence || 100,
        assumptions: Array.isArray(projectPlan.assumptions) ? projectPlan.assumptions : [],
        unknowns: Array.isArray(projectPlan.unknowns) ? projectPlan.unknowns : [],
        budgetAllocation,
        escrowPlan,
        status: 'AI Generated',
        workflowMetadata: {
          source: 'n8n',
          workflowVersion: metadata.workflowVersion,
          executionId: metadata.executionId,
          generatedAt: metadata.generatedAt,
          telemetry,
        },
      });

      res.status(201).json({ success: true, data: projectPlanDoc });
    } catch (err: any) {
      res.status(500).json({ success: false, error: 'Failed to import project plan', detail: err.message });
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

      const merchant = await Merchant.findOne({ userId: req.user._id });
      const isMerchant = merchant && plan.merchantId.toString() === merchant._id.toString();
      const isCustomer = plan.customerId && plan.customerId.toString() === req.user._id.toString();
      if (!isMerchant && !isCustomer) {
        res.status(403).json({ success: false, error: 'Access denied: You do not have permission to view this project plan.' });
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
      if (plans.length === 0) {
        res.status(404).json({ success: false, error: 'Project plan not found' });
        return;
      }

      const plan = plans[0];
      const merchant = await Merchant.findOne({ userId: req.user._id });
      const isMerchant = merchant && plan.merchantId.toString() === merchant._id.toString();
      const isCustomer = plan.customerId && plan.customerId.toString() === req.user._id.toString();
      if (!isMerchant && !isCustomer) {
        res.status(403).json({ success: false, error: 'Access denied: You do not have permission to view this project plan.' });
        return;
      }

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

      const merchant = await Merchant.findOne({ userId: req.user._id });
      const isMerchant = merchant && plan.merchantId.toString() === merchant._id.toString();
      const isCustomer = plan.customerId && plan.customerId.toString() === req.user._id.toString();
      if (!isMerchant && !isCustomer) {
        res.status(403).json({ success: false, error: 'Access denied: You do not have permission to view this project plan.' });
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

      const merchant = await Merchant.findOne({ userId: req.user._id });
      if (!merchant || latestPlan.merchantId.toString() !== merchant._id.toString()) {
        res.status(403).json({ success: false, error: 'Access denied: You do not own this project plan.' });
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

      const merchant = await Merchant.findOne({ userId: req.user._id });
      if (!merchant || latestPlan.merchantId.toString() !== merchant._id.toString()) {
        res.status(403).json({ success: false, error: 'Access denied: You do not own this project plan.' });
        return;
      }

      if (['Approved', 'Invoice Created', 'Escrow Created'].includes(latestPlan.status)) {
        res.status(400).json({ success: false, error: 'Cannot regenerate an approved or locked project plan' });
        return;
      }

      const activeRequirements = requirements || latestPlan.requirements;
      const activeTotalPaise = totalAmountPaise || latestPlan.milestones.reduce((sum, m) => sum + m.amountPaise, 0);

      const generatedPlan = await generateProjectPlanWithNemotron(
        activeRequirements,
        activeTotalPaise
      );

      const planFields = mapNemotronPlanToDbFields(generatedPlan, activeTotalPaise);

      const projectPlan = await ProjectPlan.create({
        planId,
        version: latestPlan.version + 1,
        merchantId: latestPlan.merchantId,
        customerId: customerId || latestPlan.customerId,
        requirements: activeRequirements,
        ...planFields,
        provider: 'nemotron',
        model: env.PLANNER_MODEL,
        rawAiOutput: generatedPlan,
        generatedAt: new Date(),
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

      const merchant = await Merchant.findOne({ userId: req.user._id });
      if (!merchant || latestPlan.merchantId.toString() !== merchant._id.toString()) {
        res.status(403).json({ success: false, error: 'Access denied: You do not own this project plan.' });
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
        auditRequired: true,
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
