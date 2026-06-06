import { describe, it, expect, vi, beforeEach } from 'vitest';

// Mock env variables
vi.mock('../../src/config/env', () => ({
  env: {
    NODE_ENV: 'test',
    GEMINI_API_KEY: 'mock-gemini-key',
  },
}));

// Mock Mongoose models
vi.mock('../../src/models/ProjectPlan', () => ({
  ProjectPlan: {
    findOne: vi.fn(),
  },
}));

vi.mock('../../src/models/GitHubAudit', () => {
  const mockSave = vi.fn().mockImplementation(function (this: any) {
    return Promise.resolve(this);
  });
  return {
    GitHubAudit: {
      findOne: vi.fn(),
      find: vi.fn().mockReturnValue({
        sort: vi.fn().mockResolvedValue([]),
      }),
      countDocuments: vi.fn(),
      create: vi.fn().mockImplementation((data) => Promise.resolve({
        save: mockSave,
        ...data,
      })),
    },
  };
});

vi.mock('../../src/models/GitHubAuditSnapshot', () => {
  const mockSave = vi.fn().mockImplementation(function (this: any) {
    return Promise.resolve(this);
  });
  return {
    GitHubAuditSnapshot: {
      findOne: vi.fn(),
      create: vi.fn().mockImplementation((data) => Promise.resolve({
        save: mockSave,
        ...data,
      })),
    },
  };
});

// Mock githubMcp service
vi.mock('../../src/services/githubMcp.service', () => ({
  githubMcpService: {
    connectRepository: vi.fn().mockResolvedValue(true),
    normalizeSnapshot: vi.fn().mockResolvedValue({
      repositoryTree: ['package.json', 'src/app.ts'],
      commitHashes: ['c8f391a2bb28384818cc65fa28a8a65bb919a3b2'],
      prMetadata: { title: 'Implement DB' },
      workflowRuns: { total_count: 1 },
      releaseTags: [],
      sha256Hash: 'mock-sha256-hash-signature',
    }),
  },
}));

// Mock ai.service
vi.mock('../../src/services/ai.service', () => ({
  auditMilestoneCompletion: vi.fn().mockResolvedValue({
    auditStatus: 'PASSED',
    releaseRecommendation: 'RECOMMEND_RELEASE',
    confidenceScore: 92,
    releaseConfidenceScore: 88,
    auditSummary: 'AI Auditor verifies all project requirements are met.',
    findings: 'Repository structure matches expectation. Commits check out.',
    implementationCoverage: 95,
    missingRequirements: [],
    securityIssues: [],
    performanceIssues: [],
    architectureIssues: [],
    recommendedActions: [],
    requirementTraceMatrix: [
      {
        requirementId: 'REQ-001',
        requirementText: 'Implement DB Schema',
        completionPercentage: 100,
        confidenceScore: 95,
        evidenceFiles: ['src/models/ProjectPlan.ts'],
        evidenceCommits: ['commit1'],
        evidencePRs: ['1'],
        status: 'PASSED',
      },
    ],
  }),
}));

import { githubAuditService } from '../../src/services/githubAudit.service';
import { ProjectPlan } from '../../src/models/ProjectPlan';
import { GitHubAudit } from '../../src/models/GitHubAudit';
import { GitHubAuditSnapshot } from '../../src/models/GitHubAuditSnapshot';
import { githubMcpService } from '../../src/services/githubMcp.service';

describe('GitHub Audit & Milestone Verification Service', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('connectRepository', () => {
    it('should extract details from repo URL and persist connection details on ProjectPlan', async () => {
      const mockPlan = {
        planId: 'PLAN-123',
        save: vi.fn().mockResolvedValue(true),
      };

      vi.mocked(ProjectPlan.findOne).mockResolvedValue(mockPlan as any);

      const result = await githubAuditService.connectRepository(
        'PLAN-123',
        'https://github.com/madhavansingh/ZeroPay-app',
        'main'
      );

      expect(ProjectPlan.findOne).toHaveBeenCalledWith({ planId: 'PLAN-123' });
      expect(mockPlan.save).toHaveBeenCalled();
      expect(result.owner).toBe('madhavansingh');
      expect(result.name).toBe('ZeroPay-app');
    });
  });

  describe('runMilestoneAudit', () => {
    it('should complete milestone audit, freeze immutable snapshot and track timeline history', async () => {
      const mockPlan = {
        planId: 'PLAN-123',
        invoiceId: 'INV-123',
        merchantId: 'merch-123',
        customerId: 'cust-123',
        repositoryUrl: 'https://github.com/madhavansingh/ZeroPay-app',
        repositoryOwner: 'madhavansingh',
        repositoryName: 'ZeroPay-app',
        branch: 'main',
        milestones: [
          {
            milestoneId: 'MS-1',
            title: 'Phase 1',
            githubAuditRequirements: {
              requiredFiles: ['package.json'],
              requiredFeatures: ['Database Schema'],
            },
          },
        ],
        save: vi.fn(),
      };

      vi.mocked(ProjectPlan.findOne).mockResolvedValue(mockPlan as any);
      vi.mocked(GitHubAudit.countDocuments).mockResolvedValue(0); // First audit
      vi.mocked(GitHubAudit.find).mockReturnValue({
        sort: vi.fn().mockResolvedValue([]), // First audit, no previous audits
      } as any);

      const auditLog = await githubAuditService.runMilestoneAudit(
        'PLAN-123',
        'MS-1',
        'user-123',
        'request-123'
      );

      // Verify Service Orchestration
      expect(githubMcpService.normalizeSnapshot).toHaveBeenCalledWith('madhavansingh', 'ZeroPay-app', 'main');
      
      // Verify persistence calls
      expect(GitHubAudit.create).toHaveBeenCalled();
      expect(GitHubAuditSnapshot.create).toHaveBeenCalled();

      // Check return payload validation
      expect(auditLog.auditStatus).toBe('PASSED');
      expect(auditLog.releaseConfidenceScore).toBe(88);
      expect(auditLog.auditNumber).toBe(1);
    });

    it('should compute delta changes when previous audits exist', async () => {
      const mockPlan = {
        planId: 'PLAN-123',
        invoiceId: 'INV-123',
        merchantId: 'merch-123',
        customerId: 'cust-123',
        repositoryUrl: 'https://github.com/madhavansingh/ZeroPay-app',
        repositoryOwner: 'madhavansingh',
        repositoryName: 'ZeroPay-app',
        branch: 'main',
        milestones: [
          {
            milestoneId: 'MS-1',
            title: 'Phase 1',
            githubAuditRequirements: {
              requiredFiles: ['package.json'],
              requiredFeatures: ['Database Schema'],
            },
          },
        ],
        save: vi.fn(),
      };

      const mockPrevAudit = {
        auditId: 'AUDIT-PREV',
        auditNumber: 1,
        implementationCoverage: 80,
        requirementTraceMatrix: [
          {
            requirementId: 'REQ-001',
            status: 'FAILED',
          },
        ],
        githubMetadata: {
          commitsCount: 1,
        },
      };

      vi.mocked(ProjectPlan.findOne).mockResolvedValue(mockPlan as any);
      vi.mocked(GitHubAudit.countDocuments).mockResolvedValue(1); // Second audit
      vi.mocked(GitHubAudit.findOne).mockResolvedValue(mockPrevAudit as any);
      vi.mocked(GitHubAudit.find).mockReturnValue({
        sort: vi.fn().mockResolvedValue([mockPrevAudit]),
      } as any);

      const auditLog = await githubAuditService.runMilestoneAudit(
        'PLAN-123',
        'MS-1',
        'user-123',
        'request-123'
      );

      // Verify revision calculations
      expect(auditLog.auditNumber).toBe(2);
      expect(auditLog.previousAuditId).toBe('AUDIT-PREV');
      expect(auditLog.deltaChanges?.newCoverage).toBe(15); // 95 - 80
      expect(auditLog.deltaChanges?.newRequirementsCompleted).toContain('REQ-001'); // was failed, now passed
    });
  });
});
