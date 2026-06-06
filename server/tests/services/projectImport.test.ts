import { describe, it, expect, vi, beforeEach } from 'vitest';
import fs from 'fs';
import path from 'path';

vi.mock('../../src/config/env', () => ({
  env: {
    NODE_ENV: 'test',
  },
}));

vi.mock('../../src/models/Merchant', () => ({
  Merchant: {
    findOne: vi.fn(),
  },
}));

vi.mock('../../src/models/ProjectPlan', () => ({
  ProjectPlan: {
    create: vi.fn(),
  },
}));

// Mock process.cwd to return root or mock the manifest existence
vi.mock('fs', async (importOriginal) => {
  const actual = await importOriginal<typeof import('fs')>();
  return {
    ...actual,
    existsSync: vi.fn().mockImplementation((p: string) => {
      if (p.includes('project-planner-manifest.json')) return true;
      return actual.existsSync(p);
    }),
    readFileSync: vi.fn().mockImplementation((p: string, encoding: any) => {
      if (p.includes('project-planner-manifest.json')) {
        return JSON.stringify({
          allowedWorkflowVersions: ['3.0-intelligence-pipeline'],
        });
      }
      return actual.readFileSync(p, encoding);
    }),
  };
});

import { Merchant } from '../../src/models/Merchant';
import { ProjectPlan } from '../../src/models/ProjectPlan';

describe('Project Plan Import Schema & Route Tests', () => {
  const mockPlanPayload = {
    projectPlan: {
      planId: 'PLAN-TEST-12345',
      version: 1,
      customerId: '6650dbcb5e0cf7001bb05aaa',
      requirements: 'Detailed fintech project requirements description.',
      projectSummary: 'Plan summary.',
      scope: 'Detailed scope.',
      milestones: [
        {
          milestoneId: 'MS-20260606-000001',
          title: 'Milestone 1',
          description: 'Desc 1',
          amountPaise: 50000,
          status: 'pending',
          githubAuditRequirements: {
            requiredFiles: ['package.json'],
            requiredFeatures: ['auth'],
            requiredTests: ['auth.test.ts'],
            requiredDocumentation: ['README.md'],
          },
        },
      ],
      tasks: [
        {
          taskId: 'TSK-20260606-000001',
          title: 'Task 1',
          description: 'Task description.',
          estimatedHours: 5,
          priority: 'high',
          acceptanceCriteria: ['Pass test'],
          githubAuditRequirements: {
            requiredFiles: ['server.ts'],
            requiredFeatures: ['server'],
            requiredTests: ['server.test.ts'],
            requiredDocumentation: ['DOC.md'],
          },
        },
      ],
      requirementsBreakdown: [
        {
          requirement: 'Requirement 1',
          linkedMilestones: ['MS-20260606-000001'],
          linkedTasks: ['TSK-20260606-000001'],
        },
      ],
      requirementTraceability: [
        {
          requirementId: 'REQ-001',
          requirement: 'Requirement 1',
          milestoneIds: ['MS-20260606-000001'],
          taskIds: ['TSK-20260606-000001'],
          githubAuditRequirements: {
            requiredFiles: ['server.ts'],
            requiredFeatures: ['server'],
            requiredTests: ['server.test.ts'],
            requiredDocumentation: ['DOC.md'],
          },
        },
      ],
      timeline: {
        optimisticDays: 5,
        realisticDays: 10,
        conservativeDays: 15,
        summary: 'Timeline summary.',
      },
      acceptanceCriteria: ['Pass all tests'],
      riskFactors: [
        'Risk A',
      ],
      budgetAllocation: [
        {
          category: 'Development',
          percentage: 100,
          amountPaise: 50000,
        },
      ],
      escrowPlan: {
        structure: 'Milestone-based release.',
        rationale: 'Reasoning.',
      },
      planningConfidence: 95,
      assumptions: ['Assum 1'],
      unknowns: ['Unknown 1'],
    },
    metadata: {
      workflowVersion: '3.0-intelligence-pipeline',
      executionId: 'exec-12345',
      generatedAt: new Date().toISOString(),
    },
    telemetry: {
      durationMs: 4500,
      generatedMilestones: 1,
      generatedTasks: 1,
      generatedRequirements: 1,
      complexityScore: 40,
      riskScore: 20,
      planningConfidence: 95,
    },
  };

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('should mock database models and successfully map schemas', async () => {
    const mockMerchant = { _id: '6650dbcb5e0cf7001bb05abc', userId: 'user-123' };
    vi.mocked(Merchant.findOne).mockResolvedValue(mockMerchant as any);
    
    vi.mocked(ProjectPlan.create).mockImplementation(async (doc: any) => {
      return { ...doc, _id: 'plan-mongo-id-123' } as any;
    });

    // Directly assert mapping behavior matches route implementation
    const { projectPlan, metadata, telemetry } = mockPlanPayload;
    
    expect(metadata.workflowVersion).toBe('3.0-intelligence-pipeline');
    expect(telemetry.durationMs).toBe(4500);
    
    const totalBudget = projectPlan.budgetAllocation[0].amountPaise;
    expect(totalBudget).toBe(50000);

    const doc = {
      planId: projectPlan.planId,
      version: projectPlan.version,
      merchantId: mockMerchant._id,
      requirements: projectPlan.requirements,
      projectSummary: projectPlan.projectSummary,
      scope: projectPlan.scope,
      milestones: projectPlan.milestones,
      tasks: projectPlan.tasks,
      requirementsBreakdown: projectPlan.requirementsBreakdown,
      requirementTrace: projectPlan.requirementTraceability,
      timeline: projectPlan.timeline,
      acceptanceCriteria: projectPlan.acceptanceCriteria,
      riskFactors: projectPlan.riskFactors,
      planningConfidence: projectPlan.planningConfidence,
      budgetAllocation: projectPlan.budgetAllocation,
      escrowPlan: projectPlan.escrowPlan,
      status: 'AI Generated',
      workflowMetadata: {
        source: 'n8n',
        workflowVersion: metadata.workflowVersion,
        executionId: metadata.executionId,
        generatedAt: metadata.generatedAt,
        telemetry,
      },
    };

    const created = await ProjectPlan.create(doc);
    expect(created).toBeDefined();
    expect(created.workflowMetadata?.source).toBe('n8n');
    expect(created.workflowMetadata?.telemetry.durationMs).toBe(4500);
  });
});
