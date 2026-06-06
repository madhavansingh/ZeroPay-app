import mongoose, { Document, Schema, Model } from 'mongoose';

export interface IRequirementTraceItem {
  requirementId: string;
  requirementText: string;
  completionPercentage: number;
  confidenceScore: number;
  evidenceFiles: string[];
  evidenceCommits: string[];
  evidencePRs: string[];
  status: 'PASSED' | 'PARTIAL' | 'FAILED' | 'INSUFFICIENT_EVIDENCE';
}

export interface IGitHubAudit extends Document {
  auditId: string; // AUDIT-YYYYMMDD-XXXXXX
  projectPlanId: string;
  invoiceId: string;
  milestoneId: string;
  merchantId: mongoose.Types.ObjectId;
  customerId?: mongoose.Types.ObjectId;
  repositoryUrl: string;
  repositoryOwner: string;
  repositoryName: string;
  branch: string;
  commitHash: string;
  pullRequestNumber?: number;
  auditStatus: 'PASSED' | 'PARTIALLY_COMPLETED' | 'FAILED' | 'INSUFFICIENT_EVIDENCE';
  releaseRecommendation: 'RECOMMEND_RELEASE' | 'RECOMMEND_MINOR_FIXES' | 'RECOMMEND_MAJOR_REWORK' | 'RECOMMEND_DISPUTE_REVIEW';
  confidenceScore: number; // 0-100
  releaseConfidenceScore: number; // 0-100
  auditSummary: string;
  findings: string;
  implementationCoverage: number; // 0-100
  missingRequirements: string[];
  securityIssues: string[];
  performanceIssues: string[];
  architectureIssues: string[];
  recommendedActions: string[];
  requirementTraceMatrix: IRequirementTraceItem[];
  auditNumber: number;
  previousAuditId?: string;
  deltaChanges?: {
    newCommitsCount: number;
    newCoverage: number;
    newRequirementsCompleted: string[];
    deltaSummary: string;
  };
  githubMetadata?: Record<string, any>;
  tokensUsed?: number;
  executionDurationMs?: number;
  createdAt: Date;
  updatedAt: Date;
}

const requirementTraceItemSchema = new Schema<IRequirementTraceItem>({
  requirementId: { type: String, required: true },
  requirementText: { type: String, required: true },
  completionPercentage: { type: Number, required: true, min: 0, max: 100 },
  confidenceScore: { type: Number, required: true, min: 0, max: 100 },
  evidenceFiles: { type: [String], default: [] },
  evidenceCommits: { type: [String], default: [] },
  evidencePRs: { type: [String], default: [] },
  status: {
    type: String,
    enum: ['PASSED', 'PARTIAL', 'FAILED', 'INSUFFICIENT_EVIDENCE'],
    required: true,
  },
});

const gitHubAuditSchema = new Schema<IGitHubAudit>(
  {
    auditId: { type: String, required: true, unique: true, index: true },
    projectPlanId: { type: String, required: true, index: true },
    invoiceId: { type: String, required: true, index: true },
    milestoneId: { type: String, required: true, index: true },
    merchantId: { type: Schema.Types.ObjectId, ref: 'Merchant', required: true, index: true },
    customerId: { type: Schema.Types.ObjectId, ref: 'User', index: true },
    repositoryUrl: { type: String, required: true },
    repositoryOwner: { type: String, required: true },
    repositoryName: { type: String, required: true },
    branch: { type: String, required: true },
    commitHash: { type: String, required: true },
    pullRequestNumber: { type: Number },
    auditStatus: {
      type: String,
      enum: ['PASSED', 'PARTIALLY_COMPLETED', 'FAILED', 'INSUFFICIENT_EVIDENCE'],
      required: true,
      index: true,
    },
    releaseRecommendation: {
      type: String,
      enum: ['RECOMMEND_RELEASE', 'RECOMMEND_MINOR_FIXES', 'RECOMMEND_MAJOR_REWORK', 'RECOMMEND_DISPUTE_REVIEW'],
      required: true,
      index: true,
    },
    confidenceScore: { type: Number, required: true, min: 0, max: 100 },
    releaseConfidenceScore: { type: Number, required: true, min: 0, max: 100 },
    auditSummary: { type: String, required: true },
    findings: { type: String, required: true },
    implementationCoverage: { type: Number, required: true, min: 0, max: 100 },
    missingRequirements: { type: [String], default: [] },
    securityIssues: { type: [String], default: [] },
    performanceIssues: { type: [String], default: [] },
    architectureIssues: { type: [String], default: [] },
    recommendedActions: { type: [String], default: [] },
    requirementTraceMatrix: { type: [requirementTraceItemSchema], default: [] },
    auditNumber: { type: Number, required: true, default: 1 },
    previousAuditId: { type: String, index: true },
    deltaChanges: {
      newCommitsCount: { type: Number, default: 0 },
      newCoverage: { type: Number, default: 0 },
      newRequirementsCompleted: { type: [String], default: [] },
      deltaSummary: { type: String, default: '' },
    },
    githubMetadata: { type: Schema.Types.Mixed },
    tokensUsed: { type: Number },
    executionDurationMs: { type: Number },
  },
  {
    timestamps: true,
    versionKey: false,
  }
);

// Compound index for retrieval history timeline
gitHubAuditSchema.index({ projectPlanId: 1, milestoneId: 1, auditNumber: -1 });

export const GitHubAudit: Model<IGitHubAudit> = mongoose.model<IGitHubAudit>('GitHubAudit', gitHubAuditSchema);
