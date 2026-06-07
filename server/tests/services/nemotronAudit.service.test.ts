import { describe, it, expect, vi, beforeEach } from 'vitest';
import axios from 'axios';

vi.mock('axios');

// Mock Mongoose models at top level to prevent recompilation and OverwriteModelError
vi.mock('../../src/models/Invoice', () => ({
  Invoice: {},
}));
vi.mock('../../src/models/Evidence', () => ({
  Evidence: {},
}));
vi.mock('../../src/models/ProjectPlan', () => ({
  ProjectPlan: {},
}));
vi.mock('../../src/models/AIAuditLog', () => ({
  AIAuditLog: {
    create: vi.fn().mockImplementation((data) => Promise.resolve(data)),
  },
}));

describe('NVIDIA Nemotron Codebase Audit Service Tests', () => {
  beforeEach(() => {
    vi.resetModules();
    vi.clearAllMocks();
  });

  describe('truncateSnapshot', () => {
    it('should truncate arrays exceeding env limits and report truncation details', async () => {
      vi.doMock('../../src/config/env', () => ({
        env: {
          NODE_ENV: 'test',
          GEMINI_API_KEY: 'mock-gemini-key',
          NVIDIA_API_KEY: 'mock-nvidia-key',
          AUDIT_MAX_FILES: 3,
          AUDIT_MAX_COMMITS: 2,
          AUDIT_MAX_PULL_REQUESTS: 1,
          AUDIT_MAX_WORKFLOW_RUNS: 1,
        },
      }));

      const { truncateSnapshot } = await import('../../src/services/nemotronAudit.service');

      const mockSnapshot = {
        repositoryUrl: 'https://github.com/test/repo',
        branch: 'main',
        repositoryTree: ['file1.ts', 'file2.ts', 'file3.ts', 'file4.ts'],
        commitHashes: ['commit1', 'commit2', 'commit3'],
        prMetadata: {
          pullsList: [
            { number: 1, title: 'PR 1' },
            { number: 2, title: 'PR 2' }
          ]
        },
        workflowRuns: {
          workflow_runs: [
            { id: 1, name: 'Run 1' },
            { id: 2, name: 'Run 2' }
          ]
        },
        releaseTags: ['v1.0.0'],
        sha256Hash: 'mockhash'
      };

      const { truncatedSnapshot, wasTruncated, details } = truncateSnapshot(mockSnapshot);

      expect(wasTruncated).toBe(true);
      expect(truncatedSnapshot.repositoryTree).toHaveLength(3);
      expect(truncatedSnapshot.commitHashes).toHaveLength(2);
      expect(truncatedSnapshot.prMetadata.pullsList).toHaveLength(1);
      expect(truncatedSnapshot.workflowRuns.workflow_runs).toHaveLength(1);
      expect(details).toContain('Files list truncated to first 3 files.');
      expect(details).toContain('Commit history truncated to first 2 commits.');
      expect(details).toContain('Pull requests list truncated to first 1 entries.');
      expect(details).toContain('Workflow runs list truncated to first 1 runs.');
    });

    it('should not truncate arrays if they are below env limits', async () => {
      vi.doMock('../../src/config/env', () => ({
        env: {
          NODE_ENV: 'test',
          GEMINI_API_KEY: 'mock-gemini-key',
          NVIDIA_API_KEY: 'mock-nvidia-key',
          AUDIT_MAX_FILES: 10,
          AUDIT_MAX_COMMITS: 10,
          AUDIT_MAX_PULL_REQUESTS: 10,
          AUDIT_MAX_WORKFLOW_RUNS: 10,
        },
      }));

      const { truncateSnapshot } = await import('../../src/services/nemotronAudit.service');

      const mockSnapshot = {
        repositoryUrl: 'https://github.com/test/repo',
        branch: 'main',
        repositoryTree: ['file1.ts'],
        commitHashes: ['commit1'],
        prMetadata: { pullsList: [] },
        workflowRuns: { workflow_runs: [] },
        releaseTags: [],
        sha256Hash: 'mockhash'
      };

      const { wasTruncated, details } = truncateSnapshot(mockSnapshot);

      expect(wasTruncated).toBe(false);
      expect(details).toHaveLength(0);
    });
  });

  describe('auditMilestoneCompletionWithNemotron - Mock Mode', () => {
    it('should return mock audit response when NVIDIA_API_KEY starts with mock-', async () => {
      vi.doMock('../../src/config/env', () => ({
        env: {
          NODE_ENV: 'test',
          GEMINI_API_KEY: 'mock-gemini-key',
          NVIDIA_API_KEY: 'mock-key',
          PLANNER_MODEL: 'nvidia/llama-3.3-nemotron-super-49b-v1',
          AUDIT_MAX_FILES: 10,
          AUDIT_MAX_COMMITS: 10,
          AUDIT_MAX_PULL_REQUESTS: 10,
          AUDIT_MAX_WORKFLOW_RUNS: 10,
        },
      }));

      const { auditMilestoneCompletionWithNemotron } = await import('../../src/services/nemotronAudit.service');
      const { AIAuditLog } = await import('../../src/models/AIAuditLog');

      const mockSnapshot = {
        repositoryUrl: 'https://github.com/test/repo',
        branch: 'main',
        repositoryTree: ['src/app.ts'],
        commitHashes: ['commit1'],
        prMetadata: { pullsList: [] },
        workflowRuns: { workflow_runs: [] },
        releaseTags: [],
        sha256Hash: 'mockhash'
      };

      const mockProjectPlan = {
        planId: 'PLAN-123',
        requirements: 'Requirement spec text',
        requirementTrace: [
          {
            requirementId: 'REQ-1',
            requirement: 'Verify login functionality',
            githubAuditRequirements: {
              requiredFiles: ['src/app.ts']
            }
          }
        ],
        milestones: [
          {
            milestoneId: 'MS-1',
            title: 'Setup MVP'
          }
        ]
      };

      const result = await auditMilestoneCompletionWithNemotron(
        mockSnapshot,
        mockProjectPlan,
        'MS-1',
        'user-123',
        'req-123'
      );

      expect(result.auditStatus).toBe('PASSED');
      expect(result.releaseRecommendation).toBe('RECOMMEND_RELEASE');
      expect(result.requirementTraceMatrix).toHaveLength(1);
      expect(result.requirementTraceMatrix[0].requirementId).toBe('REQ-1');
      expect(AIAuditLog.create).toHaveBeenCalled();
    });

    it('should append truncation warning to findings in mock mode if snapshot was truncated', async () => {
      vi.doMock('../../src/config/env', () => ({
        env: {
          NODE_ENV: 'test',
          GEMINI_API_KEY: 'mock-gemini-key',
          NVIDIA_API_KEY: 'mock-key',
          PLANNER_MODEL: 'nvidia/llama-3.3-nemotron-super-49b-v1',
          AUDIT_MAX_FILES: 1,
          AUDIT_MAX_COMMITS: 10,
          AUDIT_MAX_PULL_REQUESTS: 10,
          AUDIT_MAX_WORKFLOW_RUNS: 10,
        },
      }));

      const { auditMilestoneCompletionWithNemotron } = await import('../../src/services/nemotronAudit.service');

      const mockSnapshot = {
        repositoryUrl: 'https://github.com/test/repo',
        branch: 'main',
        repositoryTree: ['src/app.ts', 'src/db.ts'],
        commitHashes: ['commit1'],
        prMetadata: { pullsList: [] },
        workflowRuns: { workflow_runs: [] },
        releaseTags: [],
        sha256Hash: 'mockhash'
      };

      const mockProjectPlan = {
        planId: 'PLAN-123',
        requirements: 'Requirement spec text',
        requirementTrace: [],
        milestones: [{ milestoneId: 'MS-1', title: 'Setup' }]
      };

      const result = await auditMilestoneCompletionWithNemotron(
        mockSnapshot,
        mockProjectPlan,
        'MS-1'
      );

      expect(result.findings).toContain('[Context Warning]');
      expect(result.findings).toContain('Files list truncated to first 1 files.');
    });
  });

  describe('auditMilestoneCompletionWithNemotron - Production API Mode', () => {
    const validAuditOutput = {
      auditStatus: 'PASSED',
      releaseRecommendation: 'RECOMMEND_RELEASE',
      confidenceScore: 95,
      releaseConfidenceScore: 90,
      auditSummary: 'All requirements checked.',
      findings: 'Code looks clean.',
      implementationCoverage: 100,
      missingRequirements: [],
      securityIssues: [],
      performanceIssues: [],
      architectureIssues: [],
      recommendedActions: ['Release funds.'],
      requirementTraceMatrix: [
        {
          requirementId: 'REQ-1',
          requirementText: 'Verify login',
          completionPercentage: 100,
          confidenceScore: 95,
          evidenceFiles: ['src/app.ts'],
          evidenceCommits: ['commit1'],
          evidencePRs: ['1'],
          status: 'PASSED'
        }
      ],
      explainability: {
        whyVerdictAssigned: 'Clean build.',
        evidenceUsed: 'Files checked.',
        missingImplementation: 'None.',
        suggestedFixes: 'None.'
      }
    };

    it('should call NVIDIA API and return audit response when key is real', async () => {
      vi.doMock('../../src/config/env', () => ({
        env: {
          NODE_ENV: 'test',
          GEMINI_API_KEY: 'mock-gemini-key',
          NVIDIA_API_KEY: 'nvapi-real-key-123',
          PLANNER_MODEL: 'nvidia/llama-3.3-nemotron-super-49b-v1',
          AUDIT_MAX_FILES: 10,
          AUDIT_MAX_COMMITS: 10,
          AUDIT_MAX_PULL_REQUESTS: 10,
          AUDIT_MAX_WORKFLOW_RUNS: 10,
        },
      }));

      vi.mocked(axios.post).mockResolvedValueOnce({
        data: {
          choices: [
            {
              message: {
                content: JSON.stringify(validAuditOutput),
              },
            },
          ],
        },
      });

      const { auditMilestoneCompletionWithNemotron } = await import('../../src/services/nemotronAudit.service');

      const mockSnapshot = {
        repositoryUrl: 'https://github.com/test/repo',
        branch: 'main',
        repositoryTree: ['src/app.ts'],
        commitHashes: ['commit1'],
        prMetadata: { pullsList: [] },
        workflowRuns: { workflow_runs: [] },
        releaseTags: [],
        sha256Hash: 'mockhash'
      };

      const mockProjectPlan = {
        planId: 'PLAN-123',
        requirements: 'Requirement spec text',
        requirementTrace: [],
        milestones: [{ milestoneId: 'MS-1', title: 'Setup' }]
      };

      const result = await auditMilestoneCompletionWithNemotron(
        mockSnapshot,
        mockProjectPlan,
        'MS-1'
      );

      expect(result.auditStatus).toBe('PASSED');
      expect(result.releaseConfidenceScore).toBe(90);
      expect(axios.post).toHaveBeenCalledTimes(1);
    });

    it('should successfully repair markdown-wrapped JSON and parse it', async () => {
      vi.doMock('../../src/config/env', () => ({
        env: {
          NODE_ENV: 'test',
          GEMINI_API_KEY: 'mock-gemini-key',
          NVIDIA_API_KEY: 'nvapi-real-key-123',
          PLANNER_MODEL: 'nvidia/llama-3.3-nemotron-super-49b-v1',
          AUDIT_MAX_FILES: 10,
          AUDIT_MAX_COMMITS: 10,
          AUDIT_MAX_PULL_REQUESTS: 10,
          AUDIT_MAX_WORKFLOW_RUNS: 10,
        },
      }));

      const markdownWrapped = `\`\`\`json\n${JSON.stringify(validAuditOutput)}\n\`\`\``;

      vi.mocked(axios.post).mockResolvedValueOnce({
        data: {
          choices: [
            {
              message: {
                content: markdownWrapped,
              },
            },
          ],
        },
      });

      const { auditMilestoneCompletionWithNemotron } = await import('../../src/services/nemotronAudit.service');

      const mockSnapshot = {
        repositoryUrl: 'https://github.com/test/repo',
        branch: 'main',
        repositoryTree: ['src/app.ts'],
        commitHashes: ['commit1'],
        prMetadata: { pullsList: [] },
        workflowRuns: { workflow_runs: [] },
        releaseTags: [],
        sha256Hash: 'mockhash'
      };

      const mockProjectPlan = {
        planId: 'PLAN-123',
        requirements: 'Requirement spec text',
        requirementTrace: [],
        milestones: [{ milestoneId: 'MS-1', title: 'Setup' }]
      };

      const result = await auditMilestoneCompletionWithNemotron(
        mockSnapshot,
        mockProjectPlan,
        'MS-1'
      );

      expect(result.auditStatus).toBe('PASSED');
      expect(axios.post).toHaveBeenCalledTimes(1);
    });

    it('should fallback to nano model if primary model fails', async () => {
      vi.doMock('../../src/config/env', () => ({
        env: {
          NODE_ENV: 'test',
          GEMINI_API_KEY: 'mock-gemini-key',
          NVIDIA_API_KEY: 'nvapi-real-key-123',
          PLANNER_MODEL: 'nvidia/llama-3.3-nemotron-super-49b-v1',
          AUDIT_MAX_FILES: 10,
          AUDIT_MAX_COMMITS: 10,
          AUDIT_MAX_PULL_REQUESTS: 10,
          AUDIT_MAX_WORKFLOW_RUNS: 10,
        },
      }));

      vi.mocked(axios.post)
        .mockRejectedValueOnce(new Error('Rate limit exceeded'))
        .mockResolvedValueOnce({
          data: {
            choices: [
              {
                message: {
                  content: JSON.stringify(validAuditOutput),
                },
              },
            ],
          },
        });

      const { auditMilestoneCompletionWithNemotron } = await import('../../src/services/nemotronAudit.service');

      const mockSnapshot = {
        repositoryUrl: 'https://github.com/test/repo',
        branch: 'main',
        repositoryTree: ['src/app.ts'],
        commitHashes: ['commit1'],
        prMetadata: { pullsList: [] },
        workflowRuns: { workflow_runs: [] },
        releaseTags: [],
        sha256Hash: 'mockhash'
      };

      const mockProjectPlan = {
        planId: 'PLAN-123',
        requirements: 'Requirement spec text',
        requirementTrace: [],
        milestones: [{ milestoneId: 'MS-1', title: 'Setup' }]
      };

      const result = await auditMilestoneCompletionWithNemotron(
        mockSnapshot,
        mockProjectPlan,
        'MS-1'
      );

      expect(result.auditStatus).toBe('PASSED');
      expect(axios.post).toHaveBeenCalledTimes(2);
      expect(axios.post).toHaveBeenNthCalledWith(
        2,
        expect.any(String),
        expect.objectContaining({ model: 'nvidia/nemotron-3-nano-30b-a3b' }),
        expect.any(Object)
      );
    });

    it('should throw error if fallback also fails', async () => {
      vi.doMock('../../src/config/env', () => ({
        env: {
          NODE_ENV: 'test',
          GEMINI_API_KEY: 'mock-gemini-key',
          NVIDIA_API_KEY: 'nvapi-real-key-123',
          PLANNER_MODEL: 'nvidia/llama-3.3-nemotron-super-49b-v1',
          AUDIT_MAX_FILES: 10,
          AUDIT_MAX_COMMITS: 10,
          AUDIT_MAX_PULL_REQUESTS: 10,
          AUDIT_MAX_WORKFLOW_RUNS: 10,
        },
      }));

      vi.mocked(axios.post).mockRejectedValue(new Error('API failure'));

      const { auditMilestoneCompletionWithNemotron } = await import('../../src/services/nemotronAudit.service');

      const mockSnapshot = {
        repositoryUrl: 'https://github.com/test/repo',
        branch: 'main',
        repositoryTree: ['src/app.ts'],
        commitHashes: ['commit1'],
        prMetadata: { pullsList: [] },
        workflowRuns: { workflow_runs: [] },
        releaseTags: [],
        sha256Hash: 'mockhash'
      };

      const mockProjectPlan = {
        planId: 'PLAN-123',
        requirements: 'Requirement spec text',
        requirementTrace: [],
        milestones: [{ milestoneId: 'MS-1', title: 'Setup' }]
      };

      await expect(
        auditMilestoneCompletionWithNemotron(mockSnapshot, mockProjectPlan, 'MS-1')
      ).rejects.toThrow('API failure');

      expect(axios.post).toHaveBeenCalledTimes(2);
    });
  });
});
