import mongoose, { Document, Schema, Model } from 'mongoose';

export interface IFileReference {
  requirementId: string;
  filePath: string;
  lines?: string;
}

export interface IGitHubAuditSnapshot extends Document {
  snapshotId: string; // SNAP-YYYYMMDD-XXXXXX
  auditId: string;
  repositoryTree: string[];
  commitHashes: string[];
  prMetadata: Record<string, any>;
  workflowRuns: Record<string, any>;
  releaseTags: string[];
  fileReferences: IFileReference[];
  aiFindings: string;
  auditVerdict: string;
  sha256Hash: string; // unique hash computed over tree, commits, and PR details to guarantee reproducibility
  createdAt: Date;
  updatedAt: Date;
}

const fileReferenceSchema = new Schema<IFileReference>({
  requirementId: { type: String, required: true },
  filePath: { type: String, required: true },
  lines: { type: String },
});

const gitHubAuditSnapshotSchema = new Schema<IGitHubAuditSnapshot>(
  {
    snapshotId: { type: String, required: true, unique: true, index: true },
    auditId: { type: String, required: true, unique: true, index: true },
    repositoryTree: { type: [String], default: [] },
    commitHashes: { type: [String], default: [] },
    prMetadata: { type: Schema.Types.Mixed, default: {} },
    workflowRuns: { type: Schema.Types.Mixed, default: {} },
    releaseTags: { type: [String], default: [] },
    fileReferences: { type: [fileReferenceSchema], default: [] },
    aiFindings: { type: String, required: true },
    auditVerdict: { type: String, required: true },
    sha256Hash: { type: String, required: true, unique: true, index: true },
  },
  {
    timestamps: true,
    versionKey: false,
  }
);

export const GitHubAuditSnapshot: Model<IGitHubAuditSnapshot> = mongoose.model<IGitHubAuditSnapshot>(
  'GitHubAuditSnapshot',
  gitHubAuditSnapshotSchema
);
