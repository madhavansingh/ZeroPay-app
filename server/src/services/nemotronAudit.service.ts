import axios from 'axios';
import { env } from '../config/env';
import { logger } from '../config/logger';
import { RepositorySnapshot } from './githubMcp.service';
import { githubAuditResponseSchema, GitHubAuditResponse } from './ai.service';
import { AIAuditLog } from '../models/AIAuditLog';

const isMockMode = env.NVIDIA_API_KEY.startsWith('mock-');

const SYSTEM_PROMPT = `You are a professional codebase auditor and smart contract release safety advisor.
Evaluate the connected repository evidence (files, commits, PR comments/reviews, CI/CD runs) against the milestone requirement specifications.

Specifically evaluate:
* Milestone completion
* Requirement coverage
* File coverage
* Code quality
* Security risks
* Testing completeness
* Deployment readiness

CRITICAL VERIFICATION RULES:
1. For each requirement associated with this milestone, compile a detailed RequirementTraceMatrix entry:
   - Identify evidenceFiles (files that implement it), evidenceCommits (commits that added/modified it), and evidencePRs.
   - Set status (PASSED, PARTIAL, FAILED, INSUFFICIENT_EVIDENCE) and completionPercentage (0-100).
2. If any CI/CD workflow run is in a failed status, the overall auditStatus MUST NOT be 'PASSED'. Set it to 'FAILED' or 'PARTIALLY_COMPLETED'.
3. Calculate the releaseConfidenceScore (0-100) using the formula:
   releaseConfidenceScore = (0.4 * implementationCoverage) + (0.3 * requirementCompletionRate) + (0.15 * CI_Success_Rate) - (0.15 * Security_Issues_Count * 10)
   Ensure the score is bound between 0 and 100.
4. Set releaseRecommendation:
   - RECOMMEND_RELEASE: Audit status is PASSED and releaseConfidenceScore >= 80.
   - RECOMMEND_MINOR_FIXES: Audit status is PARTIALLY_COMPLETED/PASSED but has minor issues or releaseConfidenceScore between 70 and 79.
   - RECOMMEND_MAJOR_REWORK: Audit status is FAILED or has failing CI/CD, or releaseConfidenceScore between 40 and 69.
   - RECOMMEND_DISPUTE_REVIEW: Insufficient evidence, major security breaches, or releaseConfidenceScore < 40.
5. Provide comprehensive explainability fields.

You MUST return your response strictly as a JSON object matching this schema:
{
  "auditStatus": "PASSED | PARTIALLY_COMPLETED | FAILED | INSUFFICIENT_EVIDENCE",
  "releaseRecommendation": "RECOMMEND_RELEASE | RECOMMEND_MINOR_FIXES | RECOMMEND_MAJOR_REWORK | RECOMMEND_DISPUTE_REVIEW",
  "confidenceScore": 90,
  "releaseConfidenceScore": 85,
  "auditSummary": "Summary of the audit findings",
  "findings": "Detailed technical findings",
  "implementationCoverage": 85,
  "missingRequirements": ["list of missing requirements"],
  "securityIssues": ["list of security issues"],
  "performanceIssues": ["list of performance issues"],
  "architectureIssues": ["list of architecture issues"],
  "recommendedActions": ["actions to take"],
  "requirementTraceMatrix": [
    {
      "requirementId": "REQ-001",
      "requirementText": "Requirement text",
      "completionPercentage": 100,
      "confidenceScore": 95,
      "evidenceFiles": ["src/file.ts"],
      "evidenceCommits": ["sha123"],
      "evidencePRs": ["1"],
      "status": "PASSED"
    }
  ],
  "explainability": {
    "whyVerdictAssigned": "Explain the reason behind this verdict",
    "evidenceUsed": "Explain what evidence was verified",
    "missingImplementation": "Describe what was missing",
    "suggestedFixes": "Describe what to fix"
  }
}

Do NOT return markdown code blocks. Do NOT return conversational text or preface. Output only valid JSON.`;

/**
 * Truncate snapshot arrays according to environment limits
 */
export function truncateSnapshot(snapshot: RepositorySnapshot): {
  truncatedSnapshot: any;
  wasTruncated: boolean;
  details: string[];
} {
  const details: string[] = [];
  let wasTruncated = false;

  let tree = snapshot.repositoryTree || [];
  if (tree.length > env.AUDIT_MAX_FILES) {
    tree = tree.slice(0, env.AUDIT_MAX_FILES);
    wasTruncated = true;
    details.push(`Files list truncated to first ${env.AUDIT_MAX_FILES} files.`);
  }

  let commits = snapshot.commitHashes || [];
  if (commits.length > env.AUDIT_MAX_COMMITS) {
    commits = commits.slice(0, env.AUDIT_MAX_COMMITS);
    wasTruncated = true;
    details.push(`Commit history truncated to first ${env.AUDIT_MAX_COMMITS} commits.`);
  }

  const prMetadata = { ...snapshot.prMetadata };
  if (prMetadata && Array.isArray(prMetadata.pullsList)) {
    if (prMetadata.pullsList.length > env.AUDIT_MAX_PULL_REQUESTS) {
      prMetadata.pullsList = prMetadata.pullsList.slice(0, env.AUDIT_MAX_PULL_REQUESTS);
      wasTruncated = true;
      details.push(`Pull requests list truncated to first ${env.AUDIT_MAX_PULL_REQUESTS} entries.`);
    }
  }

  const workflowRuns = { ...snapshot.workflowRuns };
  if (workflowRuns && Array.isArray(workflowRuns.workflow_runs)) {
    if (workflowRuns.workflow_runs.length > env.AUDIT_MAX_WORKFLOW_RUNS) {
      workflowRuns.workflow_runs = workflowRuns.workflow_runs.slice(0, env.AUDIT_MAX_WORKFLOW_RUNS);
      wasTruncated = true;
      details.push(`Workflow runs list truncated to first ${env.AUDIT_MAX_WORKFLOW_RUNS} runs.`);
    }
  }

  const truncatedSnapshot = {
    ...snapshot,
    repositoryTree: tree,
    commitHashes: commits,
    prMetadata,
    workflowRuns,
  };

  return {
    truncatedSnapshot,
    wasTruncated,
    details,
  };
}

/**
 * Clean LLM markdown code blocks
 */
function attemptJSONRepair(content: string): string {
  let cleaned = content.trim();
  if (cleaned.startsWith('```')) {
    cleaned = cleaned.replace(/^```(json)?\n?/, '').replace(/\n?```$/, '').trim();
  }
  return cleaned;
}

/**
 * Execute codebase compliance audit using NVIDIA integrate API
 */
export async function auditMilestoneCompletionWithNemotron(
  snapshot: RepositorySnapshot,
  projectPlan: any,
  milestoneId: string,
  actorId: string = 'system',
  requestId?: string
): Promise<GitHubAuditResponse> {
  const startTime = Date.now();
  logger.info(`[Nemotron Audit] Starting audit for plan ${projectPlan.planId}, milestone ${milestoneId}`);

  // Enforce resource protection limits
  const { truncatedSnapshot, wasTruncated, details: truncationDetails } = truncateSnapshot(snapshot);

  if (isMockMode) {
    logger.info('[Nemotron Audit] Running in MOCK mode. Generating mock audit snapshot.');
    const mockOutput: GitHubAuditResponse = {
      auditStatus: 'PASSED',
      releaseRecommendation: 'RECOMMEND_RELEASE',
      confidenceScore: 95,
      releaseConfidenceScore: 90,
      auditSummary: 'Milestone requirements have been fully verified and tested. Code quality is high, and all unit tests pass successfully.',
      findings: 'All core modules for this milestone are fully implemented. Lint checks and security scans are passing. Verification matrix links requirements to specific codebase entries.',
      implementationCoverage: 100,
      missingRequirements: [],
      securityIssues: [],
      performanceIssues: [],
      architectureIssues: [],
      recommendedActions: ['Proceed with release of funds from escrow.'],
      requirementTraceMatrix: (projectPlan.requirementTrace || []).map((r: any) => ({
        requirementId: r.requirementId,
        requirementText: r.requirement,
        completionPercentage: 100,
        confidenceScore: 95,
        evidenceFiles: r.githubAuditRequirements?.requiredFiles || ['src/server.ts'],
        evidenceCommits: truncatedSnapshot.commitHashes || ['c8f391a2bb28384818cc65fa28a8a65bb919a3b2'],
        evidencePRs: ['1'],
        status: 'PASSED',
      })),
      explainability: {
        whyVerdictAssigned: 'All requirements have corresponding verified code files and commits. The build and test pipelines are completely green.',
        evidenceUsed: 'Inspected repo file list, verified commits, and checked PR reviews.',
        missingImplementation: 'None.',
        suggestedFixes: 'None.',
      },
    };

    if (wasTruncated) {
      mockOutput.findings += `\n\n[Context Warning]: ${truncationDetails.join(' ')}`;
    }

    await AIAuditLog.create({
      timestamp: new Date(),
      action: 'audit-milestone',
      actorId,
      requestId,
      promptTemplate: SYSTEM_PROMPT,
      inputData: { milestoneId, projectPlanId: projectPlan.planId, wasTruncated },
      rawResponse: JSON.stringify(mockOutput),
      parsedResponse: mockOutput,
      confidenceScore: 100,
      latencyMs: Date.now() - startTime,
      status: 'success',
    });

    return mockOutput;
  }

  const userPrompt = `You are auditing milestone "${milestoneId}".
Project Requirements: "${projectPlan.requirements}"
Milestone Traceability: ${JSON.stringify(projectPlan.requirementTrace || [])}
Target Milestone details: ${JSON.stringify(projectPlan.milestones.find((m: any) => m.milestoneId === milestoneId) || {})}

CONNECTED REPOSITORY SNAPSHOT:
- URL: ${truncatedSnapshot.repositoryUrl}
- Branch: ${truncatedSnapshot.branch}
- Repository Tree: ${JSON.stringify(truncatedSnapshot.repositoryTree)}
- Commit History: ${JSON.stringify(truncatedSnapshot.commitHashes)}
- Pull Request reviews & comments: ${JSON.stringify(truncatedSnapshot.prMetadata)}
- Actions Status/Runs: ${JSON.stringify(truncatedSnapshot.workflowRuns)}
- Release Tags: ${JSON.stringify(truncatedSnapshot.releaseTags)}

${wasTruncated ? `WARNING: Large repository snapshot detected. ${truncationDetails.join(' ')} Evaluate the subset of files provided.` : ''}`;

  let attempt = 0;
  const maxAttempts = 2; // Try primary then fallback model
  const models = [env.PLANNER_MODEL, 'nvidia/nemotron-3-nano-30b-a3b'];

  while (attempt < maxAttempts) {
    const selectedModel = models[attempt];
    attempt++;
    try {
      logger.info(`[Nemotron Audit] Calling NVIDIA API (Attempt ${attempt}) with model ${selectedModel}`);
      
      const response = await axios.post(
        'https://integrate.api.nvidia.com/v1/chat/completions',
        {
          model: selectedModel,
          messages: [
            { role: 'system', content: SYSTEM_PROMPT },
            { role: 'user', content: userPrompt },
          ],
          temperature: 0.1,
          max_tokens: 4096,
        },
        {
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${env.NVIDIA_API_KEY}`,
          },
          timeout: 90000, // Large snapshots require generous timeouts
        }
      );

      const content = response.data?.choices?.[0]?.message?.content;
      if (!content) {
        throw new Error('NVIDIA integrate API returned empty response.');
      }

      const repaired = attemptJSONRepair(content);
      const parsed = JSON.parse(repaired);

      // Validate Zod schema
      const result = githubAuditResponseSchema.safeParse(parsed);
      if (!result.success) {
        throw new Error(`Zod audit response schema validation failed: ${JSON.stringify(result.error.flatten())}`);
      }

      const finalAudit = result.data;
      if (wasTruncated) {
        finalAudit.findings += `\n\n[Context Warning]: ${truncationDetails.join(' ')}`;
      }

      await AIAuditLog.create({
        timestamp: new Date(),
        action: 'audit-milestone',
        actorId,
        requestId,
        promptTemplate: SYSTEM_PROMPT,
        inputData: { milestoneId, projectPlanId: projectPlan.planId, model: selectedModel, wasTruncated },
        rawResponse: content,
        parsedResponse: finalAudit,
        confidenceScore: finalAudit.confidenceScore,
        latencyMs: Date.now() - startTime,
        status: 'success',
      });

      logger.info(`[Nemotron Audit] Codebase audit successfully compiled on attempt ${attempt}`);
      return finalAudit;
    } catch (err: any) {
      logger.warn(`[Nemotron Audit] Attempt ${attempt} with model ${selectedModel} failed: ${err.message}`);
      if (attempt >= maxAttempts) {
        logger.error('[Nemotron Audit] All attempts failed permanently.');
        
        await AIAuditLog.create({
          timestamp: new Date(),
          action: 'audit-milestone',
          actorId,
          requestId,
          promptTemplate: SYSTEM_PROMPT,
          inputData: { milestoneId, projectPlanId: projectPlan.planId, wasTruncated },
          validationErrors: err.message,
          latencyMs: Date.now() - startTime,
          status: 'failure',
        });

        throw err;
      }
      logger.info('[Nemotron Audit] Retrying with fallback model...');
    }
  }

  throw new Error('NVIDIA Nemotron audit service reached unreachable code path.');
}
