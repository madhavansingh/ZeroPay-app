import { z } from 'zod';

export const PROMPT_VERSIONS = {
  GENERATE_MILESTONES: 'v2.1-milestone-structurer',
  SUMMARIZE_DISPUTE: 'v3.2-dispute-arbitrator',
  DETECT_ANOMALY: 'v1.0-anomaly-scorer',
  AUDIT_MILESTONE: 'v1.0-code-auditor',
} as const;

export interface MilestoneSuggestion {
  title: string;
  amountPaise: number;
}

export interface DisputeSummary {
  summary: string;
  keyClaims: string[];
  recommendedSplitMerchantPercent: number;
  recommendedSplitCustomerPercent: number;
  reasoning: string;
}

export interface EscrowExplanation {
  headline: string;
  details: string;
  nextActionRequiredBy: 'buyer' | 'seller' | 'admin' | 'none';
  plainEnglishStatus: string;
}

export interface AnomalyReport {
  isAnomaly: boolean;
  score: number; // 0-100
  factors: string[];
}

export interface InvoiceDraft {
  lineItems: Array<{ title: string; pricePaise: number }>;
  suggestedPrice: number;
  professionalTitle: string;
  termsText: string;
  estimatedCompletionDays: number;
}

export interface MerchantInsight {
  revenueTrendNarrative: string;
  topCategories: string[];
  pricingSuggestions: string[];
  peakHours: string;
  retentionSignals: string;
}

export interface PricingSuggestion {
  suggestedMinLovelace: number;
  suggestedMaxLovelace: number;
  benchmarkContext: string;
  rationale: string;
}

export const milestoneSuggestionSchema = z.object({
  title: z.string().min(3, 'Milestone title is too short'),
  amountPaise: z.number().int().positive('Milestone amount must be positive'),
});

export const milestonesResponseSchema = z.object({
  milestones: z.array(milestoneSuggestionSchema).min(1, 'At least one milestone is required'),
});

export const disputeSummaryResponseSchema = z.object({
  summary: z.string().min(10, 'Dispute summary must be detailed'),
  keyClaims: z.array(z.string()).min(1, 'Must extract at least one claim'),
  recommendedSplitMerchantPercent: z.number().int().min(0).max(100),
  recommendedSplitCustomerPercent: z.number().int().min(0).max(100),
  reasoning: z.string().min(10, 'Must provide full reasoning for recommended split'),
});

export const projectPlanResponseSchema = z.object({
  projectSummary: z.string().min(5),
  scope: z.string().min(5),
  milestones: z.array(
    z.object({
      title: z.string().min(3),
      description: z.string().min(5),
      percentage: z.number().int().min(1).max(100),
      timelineEstimateOptimisticDays: z.number().int().positive(),
      timelineEstimateRealisticDays: z.number().int().positive(),
      timelineEstimateConservativeDays: z.number().int().positive(),
      deliverables: z.array(z.string()).min(1),
      validationCriteria: z.array(z.string()).min(1),
      successConditions: z.array(z.string()).min(1),
      githubAuditRequirements: z.object({
        requiredFiles: z.array(z.string()),
        requiredFeatures: z.array(z.string()),
        requiredTests: z.array(z.string()),
        requiredDocumentation: z.array(z.string()),
      }),
    })
  ).min(1),
  tasks: z.array(
    z.object({
      title: z.string().min(3),
      description: z.string().min(5),
      estimatedHours: z.number().int().positive(),
      priority: z.enum(['low', 'medium', 'high']),
      acceptanceCriteria: z.array(z.string()).min(1),
      githubAuditRequirements: z.object({
        requiredFiles: z.array(z.string()),
        requiredFeatures: z.array(z.string()),
        requiredTests: z.array(z.string()),
        requiredDocumentation: z.array(z.string()),
      }),
    })
  ).min(1),
  requirementsBreakdown: z.array(
    z.object({
      requirement: z.string().min(3),
      linkedMilestoneTitles: z.array(z.string()),
      linkedTaskTitles: z.array(z.string()),
    })
  ).min(1),
  timeline: z.object({
    optimisticDays: z.number().int().positive(),
    realisticDays: z.number().int().positive(),
    conservativeDays: z.number().int().positive(),
    summary: z.string().min(5),
  }),
  acceptanceCriteria: z.array(z.string()).min(1),
  riskFactors: z.array(z.string()).min(1),
  budgetAllocation: z.array(
    z.object({
      category: z.string().min(2),
      percentage: z.number().int().min(1).max(100),
    })
  ).min(1),
  escrowPlan: z.object({
    structure: z.string().min(5),
    rationale: z.string().min(5),
  }),
  planningConfidence: z.number().int().min(0).max(100),
  assumptions: z.array(z.string()).min(1),
  unknowns: z.array(z.string()).min(1),
});

export const githubAuditResponseSchema = z.object({
  auditStatus: z.enum(['PASSED', 'PARTIALLY_COMPLETED', 'FAILED', 'INSUFFICIENT_EVIDENCE']),
  releaseRecommendation: z.enum(['RECOMMEND_RELEASE', 'RECOMMEND_MINOR_FIXES', 'RECOMMEND_MAJOR_REWORK', 'RECOMMEND_DISPUTE_REVIEW']),
  confidenceScore: z.number().int().min(0).max(100),
  releaseConfidenceScore: z.number().int().min(0).max(100),
  auditSummary: z.string(),
  findings: z.string(),
  implementationCoverage: z.number().int().min(0).max(100),
  missingRequirements: z.array(z.string()),
  securityIssues: z.array(z.string()),
  performanceIssues: z.array(z.string()),
  architectureIssues: z.array(z.string()),
  recommendedActions: z.array(z.string()),
  requirementTraceMatrix: z.array(
    z.object({
      requirementId: z.string(),
      requirementText: z.string(),
      completionPercentage: z.number().int().min(0).max(100),
      confidenceScore: z.number().int().min(0).max(100),
      evidenceFiles: z.array(z.string()),
      evidenceCommits: z.array(z.string()),
      evidencePRs: z.array(z.string()),
      status: z.enum(['PASSED', 'PARTIAL', 'FAILED', 'INSUFFICIENT_EVIDENCE']),
    })
  ),
  explainability: z.object({
    whyVerdictAssigned: z.string(),
    evidenceUsed: z.string(),
    missingImplementation: z.string(),
    suggestedFixes: z.string(),
  }),
});

export type GitHubAuditResponse = z.infer<typeof githubAuditResponseSchema>;
