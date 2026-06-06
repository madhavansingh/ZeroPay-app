import mongoose, { Document, Schema, Model } from 'mongoose';

export interface IGitHubAudit extends Document {
  githubAuditId: string;
  projectPlanId: string;
  milestoneId: string;
  auditStatus: 'pending' | 'passed' | 'failed';
  requiredFiles: string[];
  requiredFeatures: string[];
  requiredTests: string[];
  requiredDocumentation: string[];
  verifiedFiles: string[];
  verifiedTests: string[];
  verificationLogs?: string;
  createdAt: Date;
  updatedAt: Date;
}

const gitHubAuditSchema = new Schema<IGitHubAudit>(
  {
    githubAuditId: { type: String, required: true, unique: true, index: true },
    projectPlanId: { type: String, required: true, index: true },
    milestoneId: { type: String, required: true, index: true },
    auditStatus: {
      type: String,
      enum: ['pending', 'passed', 'failed'],
      default: 'pending',
      index: true,
    },
    requiredFiles: { type: [String], default: [] },
    requiredFeatures: { type: [String], default: [] },
    requiredTests: { type: [String], default: [] },
    requiredDocumentation: { type: [String], default: [] },
    verifiedFiles: { type: [String], default: [] },
    verifiedTests: { type: [String], default: [] },
    verificationLogs: { type: String },
  },
  {
    timestamps: true,
    versionKey: false,
  }
);

export const GitHubAudit: Model<IGitHubAudit> = mongoose.model<IGitHubAudit>('GitHubAudit', gitHubAuditSchema);
