import { ProjectPlan } from '../models/ProjectPlan';
import { GitHubAudit } from '../models/GitHubAudit';
import { GitHubAuditSnapshot } from '../models/GitHubAuditSnapshot';
import { githubMcpService } from './githubMcp.service';
import { auditMilestoneCompletion } from './ai.service';
import { logger } from '../config/logger';

function generateUniqueId(prefix: string): string {
  const date = new Date().toISOString().slice(0, 10).replace(/-/g, '');
  const suffix = Math.random().toString(36).substring(2, 8).toUpperCase();
  return `${prefix}-${date}-${suffix}`;
}

export const githubAuditService = {
  /**
   * Connect a GitHub repository to a project plan
   */
  async connectRepository(
    projectPlanId: string,
    repositoryUrl: string,
    branch: string = 'main'
  ): Promise<{ success: boolean; owner: string; name: string }> {
    // Parse owner and repo name from URL (e.g., https://github.com/owner/repo)
    const sanitizedUrl = repositoryUrl.replace(/\/$/, '');
    const parts = sanitizedUrl.split('/');
    if (parts.length < 2) {
      throw new Error('Invalid GitHub repository URL');
    }
    const name = parts[parts.length - 1];
    const owner = parts[parts.length - 2];

    const isAccessible = await githubMcpService.connectRepository(owner, name);
    if (!isAccessible) {
      throw new Error(`Repository ${owner}/${name} is not accessible or does not exist`);
    }

    const plan = await ProjectPlan.findOne({ planId: projectPlanId });
    if (!plan) {
      throw new Error(`Project plan not found: ${projectPlanId}`);
    }

    plan.repositoryUrl = repositoryUrl;
    plan.repositoryOwner = owner;
    plan.repositoryName = name;
    plan.branch = branch;
    await plan.save();

    logger.info(`[GitHubAuditService] Connected repo ${owner}/${name} to plan ${projectPlanId}`);
    return { success: true, owner, name };
  },

  /**
   * Run milestone code audit and persist snapshots
   */
  async runMilestoneAudit(
    projectPlanId: string,
    milestoneId: string,
    actorId: string = 'system',
    requestId?: string
  ): Promise<any> {
    const startTime = Date.now();

    const plan = await ProjectPlan.findOne({ planId: projectPlanId });
    if (!plan) {
      throw new Error(`Project plan not found: ${projectPlanId}`);
    }

    if (!plan.repositoryUrl || !plan.repositoryOwner || !plan.repositoryName) {
      throw new Error(`Project plan ${projectPlanId} is not connected to a GitHub repository`);
    }

    const owner = plan.repositoryOwner;
    const name = plan.repositoryName;
    const branch = plan.branch || 'main';

    // 1. Fetch count of existing audits to determine auditNumber
    const existingAuditsCount = await GitHubAudit.countDocuments({
      projectPlanId,
      milestoneId,
    });
    const auditNumber = existingAuditsCount + 1;

    // 2. Fetch repository snapshot from GitHub MCP
    const snapshot = await githubMcpService.normalizeSnapshot(owner, name, branch);

    // 3. Call AI Evaluation Layer
    const aiResponse = await auditMilestoneCompletion(
      snapshot,
      plan,
      milestoneId,
      actorId,
      requestId
    );

    // 4. Calculate timeline delta changes from previous audit if exists
    let previousAuditId: string | undefined;
    let deltaChanges = {
      newCommitsCount: 0,
      newCoverage: 0,
      newRequirementsCompleted: [] as string[],
      deltaSummary: 'First audit execution.',
    };

    if (auditNumber > 1) {
      const prevAudit = await GitHubAudit.findOne({
        projectPlanId,
        milestoneId,
        auditNumber: auditNumber - 1,
      });

      if (prevAudit) {
        previousAuditId = prevAudit.auditId;
        const commitsDiff = Math.max(0, snapshot.commitHashes.length - (prevAudit.githubMetadata?.commitsCount || 0));
        const coverageDiff = aiResponse.implementationCoverage - prevAudit.implementationCoverage;

        // Find newly passed requirements
        const prevPassedIds = new Set(
          prevAudit.requirementTraceMatrix
            .filter((item) => item.status === 'PASSED')
            .map((item) => item.requirementId)
        );

        const currentPassedIds = aiResponse.requirementTraceMatrix
          .filter((item) => item.status === 'PASSED')
          .map((item) => item.requirementId);

        const newlyPassed = currentPassedIds.filter((id) => !prevPassedIds.has(id));

        deltaChanges = {
          newCommitsCount: commitsDiff,
          newCoverage: coverageDiff,
          newRequirementsCompleted: newlyPassed,
          deltaSummary: `Revision ${auditNumber}: Added ${commitsDiff} new commits. Coverage changed by ${coverageDiff}%. Newly verified requirements: ${newlyPassed.join(', ') || 'none'}.`,
        };
      }
    }

    // 5. Save GitHubAudit Document
    const auditId = generateUniqueId('AUDIT');
    const githubAudit = await GitHubAudit.create({
      auditId,
      projectPlanId,
      invoiceId: plan.invoiceId || 'INV-DRAFT',
      milestoneId,
      merchantId: plan.merchantId,
      customerId: plan.customerId,
      repositoryUrl: plan.repositoryUrl,
      repositoryOwner: owner,
      repositoryName: name,
      branch,
      commitHash: snapshot.commitHashes[0] || 'unknown_commit',
      auditStatus: aiResponse.auditStatus,
      releaseRecommendation: aiResponse.releaseRecommendation,
      confidenceScore: aiResponse.confidenceScore,
      releaseConfidenceScore: aiResponse.releaseConfidenceScore,
      auditSummary: aiResponse.auditSummary,
      findings: aiResponse.findings,
      implementationCoverage: aiResponse.implementationCoverage,
      missingRequirements: aiResponse.missingRequirements,
      securityIssues: aiResponse.securityIssues,
      performanceIssues: aiResponse.performanceIssues,
      architectureIssues: aiResponse.architectureIssues,
      recommendedActions: aiResponse.recommendedActions,
      requirementTraceMatrix: aiResponse.requirementTraceMatrix,
      auditNumber,
      previousAuditId,
      deltaChanges,
      githubMetadata: {
        commitsCount: snapshot.commitHashes.length,
        workflowRunsCount: snapshot.workflowRuns?.total_count || 0,
        pullRequestTitle: snapshot.prMetadata?.title || '',
      },
      tokensUsed: 1500, // estimated
      executionDurationMs: Date.now() - startTime,
    });

    // 6. Save GitHubAuditSnapshot Document
    const snapshotId = generateUniqueId('SNAP');
    await GitHubAuditSnapshot.create({
      snapshotId,
      auditId,
      repositoryTree: snapshot.repositoryTree,
      commitHashes: snapshot.commitHashes,
      prMetadata: snapshot.prMetadata,
      workflowRuns: snapshot.workflowRuns,
      releaseTags: snapshot.releaseTags,
      fileReferences: aiResponse.requirementTraceMatrix.flatMap((item) =>
        item.evidenceFiles.map((file) => ({
          requirementId: item.requirementId,
          filePath: file,
        }))
      ),
      aiFindings: aiResponse.findings,
      auditVerdict: aiResponse.auditStatus,
      sha256Hash: snapshot.sha256Hash,
    });

    logger.info(`[GitHubAuditService] Compiled audit ${auditId} for milestone ${milestoneId} of plan ${projectPlanId}`);
    return githubAudit;
  },
};
