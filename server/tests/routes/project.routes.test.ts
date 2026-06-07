import { describe, it, expect, vi, beforeEach } from 'vitest';
import mongoose from 'mongoose';
import projectRouter from '../../src/routes/project.routes';
import { ProjectPlan } from '../../src/models/ProjectPlan';
import { Merchant } from '../../src/models/Merchant';

vi.mock('ioredis', () => {
  class MockRedis {
    on = vi.fn();
    info = vi.fn().mockResolvedValue('redis_version:7.0.0');
    ping = vi.fn().mockResolvedValue('PONG');
    get = vi.fn().mockResolvedValue(null);
    set = vi.fn().mockResolvedValue('OK');
    quit = vi.fn().mockResolvedValue('OK');
  }
  return {
    default: MockRedis,
    Redis: MockRedis,
  };
});

vi.mock('../../src/config/env', () => ({
  env: {
    NODE_ENV: 'test',
    NVIDIA_API_KEY: 'mock-nvidia-key',
    PLANNER_MODEL: 'nvidia/llama-3.3-nemotron-super-49b-v1',
    UPSTASH_REDIS_TLS_URL: 'rediss://mock-redis',
    GEMINI_API_KEY: 'mock-gemini-key',
  },
}));

vi.mock('../../src/middleware/auth', () => ({
  requireAuth: (req: any, res: any, next: any) => {
    req.user = {
      _id: new mongoose.Types.ObjectId('507f1f77bcf86cd799439011'),
      id: '507f1f77bcf86cd799439011',
    };
    next();
  },
  requireMerchant: (req: any, res: any, next: any) => {
    next();
  },
}));

vi.mock('../../src/middleware/rateLimit', () => ({
  aiRateLimit: (req: any, res: any, next: any) => {
    next();
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
    findOne: vi.fn(),
  },
}));

vi.mock('../../src/services/nemotron.service', () => ({
  generateProjectPlanWithNemotron: vi.fn(),
}));

function runRoute(req: any): Promise<{ res: any; body: any }> {
  return new Promise((resolve, reject) => {
    const res: any = {};
    let resolved = false;

    const finish = (body?: any) => {
      if (!resolved) {
        resolved = true;
        resolve({ res, body });
      }
    };

    res.json = vi.fn().mockImplementation((body) => {
      finish(body);
      return res;
    });

    res.status = vi.fn().mockImplementation((code) => {
      res.statusCode = code;
      return res;
    });

    res.send = vi.fn().mockImplementation((body) => {
      finish(body);
      return res;
    });

    res.locals = { requestId: 'req-123' };

    projectRouter(req, res, (err) => {
      if (err) {
        reject(err);
      } else {
        finish({ nextCalled: true });
      }
    });
  });
}

describe('Project Router Tests', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('POST /plan', () => {
    it('generates project plan using Nemotron and saves to DB', async () => {
      const mockMerchant = {
        _id: new mongoose.Types.ObjectId('507f1f77bcf86cd799439022'),
      };
      vi.mocked(Merchant.findOne).mockResolvedValue(mockMerchant as any);

      const mockNemotronPlan = {
        executiveSummary: 'Executive Summary',
        productVision: 'Product Vision',
        functionalRequirements: ['Functional Requirement 1'],
        nonFunctionalRequirements: ['Non Functional Requirement 1'],
        systemArchitecture: 'System Architecture',
        databaseDesign: 'Database Design',
        apiDesign: 'API Design',
        milestones: [
          {
            title: 'Setup',
            description: 'Setup description',
            estimatedDays: 2,
            dependencies: [],
            acceptanceCriteria: ['Setup ok'],
            deliverables: ['Files'],
            percentage: 100,
            budgetAllocation: 100000,
            releaseConditions: ['Ready'],
            githubAuditRequirements: ['package.json'],
          }
        ],
        tasks: [
          {
            title: 'Setup repo',
            description: 'Task desc',
            estimatedHours: 2,
            priority: 'high',
            acceptanceCriteria: ['Done'],
            githubAuditRequirements: ['package.json'],
          }
        ],
        acceptanceCriteria: ['AC1'],
        dependencies: ['Dep1'],
        riskAnalysis: [
          {
            description: 'Risk desc',
            severity: 'low',
            mitigation: 'Mitigation desc',
          }
        ],
        timelineEstimates: {
          optimisticDays: 1,
          realisticDays: 2,
          conservativeDays: 3,
          summary: 'Timeline summary',
        },
        deploymentStrategy: 'Deploy desc',
        testingStrategy: 'Test desc',
      };

      const { generateProjectPlanWithNemotron } = await import('../../src/services/nemotron.service');
      vi.mocked(generateProjectPlanWithNemotron).mockResolvedValue(mockNemotronPlan as any);

      const mockSavedPlan = {
        planId: 'PLAN-123',
        version: 1,
      };
      vi.mocked(ProjectPlan.create).mockResolvedValue(mockSavedPlan as any);

      const req = {
        method: 'POST',
        url: '/plan',
        body: {
          requirements: 'Build a system matching standard specifications',
          totalAmountPaise: 100000,
        },
      };

      const { res, body } = await runRoute(req);

      expect(res.status).toHaveBeenCalledWith(201);
      expect(generateProjectPlanWithNemotron).toHaveBeenCalledWith(
        'Build a system matching standard specifications',
        100000
      );
      expect(ProjectPlan.create).toHaveBeenCalledWith(
        expect.objectContaining({
          provider: 'nemotron',
          requirements: 'Build a system matching standard specifications',
        })
      );
      expect(body).toEqual({ success: true, data: mockSavedPlan });
    });
  });

  describe('POST /plan/:planId/regenerate', () => {
    it('regenerates project plan and creates a new version', async () => {
      const mockLatestPlan = {
        planId: 'PLAN-123',
        version: 1,
        requirements: 'Old requirements',
        merchantId: new mongoose.Types.ObjectId('507f1f77bcf86cd799439022'),
        milestones: [{ amountPaise: 100000 }],
        status: 'AI Generated',
      };

      const mockSort = vi.fn().mockResolvedValue(mockLatestPlan);
      vi.mocked(ProjectPlan.findOne).mockReturnValue({
        sort: mockSort,
      } as any);

      const mockNemotronPlan = {
        executiveSummary: 'Executive Summary v2',
        productVision: 'Product Vision v2',
        functionalRequirements: ['Functional Requirement 2'],
        nonFunctionalRequirements: ['Non Functional Requirement 2'],
        systemArchitecture: 'System Architecture v2',
        databaseDesign: 'Database Design v2',
        apiDesign: 'API Design v2',
        milestones: [
          {
            title: 'Setup v2',
            description: 'Setup description v2',
            estimatedDays: 3,
            dependencies: [],
            acceptanceCriteria: ['Setup ok v2'],
            deliverables: ['Files v2'],
            percentage: 100,
            budgetAllocation: 100000,
            releaseConditions: ['Ready v2'],
            githubAuditRequirements: ['package.json'],
          }
        ],
        tasks: [
          {
            title: 'Setup repo v2',
            description: 'Task desc v2',
            estimatedHours: 3,
            priority: 'high',
            acceptanceCriteria: ['Done v2'],
            githubAuditRequirements: ['package.json'],
          }
        ],
        acceptanceCriteria: ['AC2'],
        dependencies: ['Dep2'],
        riskAnalysis: [
          {
            description: 'Risk desc v2',
            severity: 'low',
            mitigation: 'Mitigation desc v2',
          }
        ],
        timelineEstimates: {
          optimisticDays: 2,
          realisticDays: 3,
          conservativeDays: 4,
          summary: 'Timeline summary v2',
        },
        deploymentStrategy: 'Deploy desc v2',
        testingStrategy: 'Test desc v2',
      };

      const { generateProjectPlanWithNemotron } = await import('../../src/services/nemotron.service');
      vi.mocked(generateProjectPlanWithNemotron).mockResolvedValue(mockNemotronPlan as any);

      const mockSavedPlan = {
        planId: 'PLAN-123',
        version: 2,
      };
      vi.mocked(ProjectPlan.create).mockResolvedValue(mockSavedPlan as any);

      const req = {
        method: 'POST',
        url: '/plan/PLAN-123/regenerate',
        body: {
          requirements: 'Build a system matching new specifications',
          totalAmountPaise: 100000,
        },
        params: {
          planId: 'PLAN-123',
        },
      };

      const { res, body } = await runRoute(req);

      expect(res.status).toHaveBeenCalledWith(201);
      expect(generateProjectPlanWithNemotron).toHaveBeenCalledWith(
        'Build a system matching new specifications',
        100000
      );
      expect(ProjectPlan.create).toHaveBeenCalledWith(
        expect.objectContaining({
          planId: 'PLAN-123',
          version: 2,
          provider: 'nemotron',
        })
      );
      expect(body).toEqual({ success: true, data: mockSavedPlan });
    });
  });
});
