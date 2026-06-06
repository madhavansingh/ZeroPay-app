import mongoose, { Document, Schema, Model } from 'mongoose';

export interface IProjectPlanMilestone {
  milestoneId: string; // MS-YYYYMMDD-XXXXXX
  title: string;
  description: string;
  amountPaise: number;
  status: 'pending' | 'released' | 'disputed';
  githubAuditRequirements: {
    requiredFiles: string[];
    requiredFeatures: string[];
    requiredTests: string[];
    requiredDocumentation: string[];
  };
}

export interface IProjectPlanTask {
  taskId: string; // TSK-YYYYMMDD-XXXXXX
  title: string;
  description: string;
  estimatedHours: number;
  priority: 'low' | 'medium' | 'high';
  acceptanceCriteria: string[];
  githubAuditRequirements: {
    requiredFiles: string[];
    requiredFeatures: string[];
    requiredTests: string[];
    requiredDocumentation: string[];
  };
}

export interface IRequirementsBreakdown {
  requirement: string;
  linkedMilestones: string[]; // milestoneIds
  linkedTasks: string[]; // taskIds
}

export interface IRequirementTrace {
  requirementId: string; // REQ-001, REQ-002, etc.
  requirement: string;
  milestoneIds: string[];
  taskIds: string[];
  githubAuditRequirements: {
    requiredFiles: string[];
    requiredFeatures: string[];
    requiredTests: string[];
    requiredDocumentation: string[];
  };
}

export interface IProjectPlanBudgetItem {
  category: string;
  percentage: number;
  amountPaise: number;
}

export interface IProjectPlan extends Document {
  planId: string;
  version: number;
  merchantId: mongoose.Types.ObjectId;
  customerId?: mongoose.Types.ObjectId;
  invoiceId?: string; // invoiceId string once created
  requirements: string;
  projectSummary: string;
  scope: string;
  milestones: IProjectPlanMilestone[];
  tasks: IProjectPlanTask[];
  requirementsBreakdown: IRequirementsBreakdown[];
  requirementTrace: IRequirementTrace[];
  timeline: {
    optimisticDays: number;
    realisticDays: number;
    conservativeDays: number;
    summary: string;
  };
  acceptanceCriteria: string[];
  riskFactors: string[];
  planningConfidence: number; // 0-100
  assumptions: string[];
  unknowns: string[];
  budgetAllocation: IProjectPlanBudgetItem[];
  escrowPlan: {
    structure: string;
    rationale: string;
  };
  repositoryUrl?: string;
  repositoryOwner?: string;
  repositoryName?: string;
  branch?: string;
  workflowMetadata?: Record<string, any>;
  status: 'Draft' | 'AI Generated' | 'User Edited' | 'Approved' | 'Invoice Created' | 'Escrow Created';
  createdAt: Date;
  updatedAt: Date;
}

const milestoneSchema = new Schema<IProjectPlanMilestone>({
  milestoneId: { type: String, required: true, index: true },
  title: { type: String, required: true },
  description: { type: String, default: '' },
  amountPaise: { type: Number, required: true },
  status: { type: String, enum: ['pending', 'released', 'disputed'], default: 'pending' },
  githubAuditRequirements: {
    requiredFiles: { type: [String], default: [] },
    requiredFeatures: { type: [String], default: [] },
    requiredTests: { type: [String], default: [] },
    requiredDocumentation: { type: [String], default: [] },
  },
});

const taskSchema = new Schema<IProjectPlanTask>({
  taskId: { type: String, required: true, index: true },
  title: { type: String, required: true },
  description: { type: String, default: '' },
  estimatedHours: { type: Number, required: true },
  priority: { type: String, enum: ['low', 'medium', 'high'], default: 'medium' },
  acceptanceCriteria: { type: [String], default: [] },
  githubAuditRequirements: {
    requiredFiles: { type: [String], default: [] },
    requiredFeatures: { type: [String], default: [] },
    requiredTests: { type: [String], default: [] },
    requiredDocumentation: { type: [String], default: [] },
  },
});

const requirementsBreakdownSchema = new Schema<IRequirementsBreakdown>({
  requirement: { type: String, required: true },
  linkedMilestones: { type: [String], default: [] },
  linkedTasks: { type: [String], default: [] },
});

const requirementTraceSchema = new Schema<IRequirementTrace>({
  requirementId: { type: String, required: true },
  requirement: { type: String, required: true },
  milestoneIds: { type: [String], default: [] },
  taskIds: { type: [String], default: [] },
  githubAuditRequirements: {
    requiredFiles: { type: [String], default: [] },
    requiredFeatures: { type: [String], default: [] },
    requiredTests: { type: [String], default: [] },
    requiredDocumentation: { type: [String], default: [] },
  },
});

const budgetAllocationSchema = new Schema<IProjectPlanBudgetItem>({
  category: { type: String, required: true },
  percentage: { type: Number, required: true },
  amountPaise: { type: Number, required: true },
});

const projectPlanSchema = new Schema<IProjectPlan>(
  {
    planId: { type: String, required: true, index: true },
    version: { type: Number, required: true, default: 1 },
    merchantId: { type: Schema.Types.ObjectId, ref: 'Merchant', required: true, index: true },
    customerId: { type: Schema.Types.ObjectId, ref: 'User', index: true },
    invoiceId: { type: String, index: true },
    requirements: { type: String, required: true },
    projectSummary: { type: String, required: true },
    scope: { type: String, required: true },
    milestones: { type: [milestoneSchema], default: [] },
    tasks: { type: [taskSchema], default: [] },
    requirementsBreakdown: { type: [requirementsBreakdownSchema], default: [] },
    requirementTrace: { type: [requirementTraceSchema], default: [] },
    timeline: {
      optimisticDays: { type: Number, required: true },
      realisticDays: { type: Number, required: true },
      conservativeDays: { type: Number, required: true },
      summary: { type: String, required: true },
    },
    acceptanceCriteria: { type: [String], default: [] },
    riskFactors: { type: [String], default: [] },
    planningConfidence: { type: Number, required: true, min: 0, max: 100 },
    assumptions: { type: [String], default: [] },
    unknowns: { type: [String], default: [] },
    budgetAllocation: { type: [budgetAllocationSchema], default: [] },
    escrowPlan: {
      structure: { type: String, required: true },
      rationale: { type: String, required: true },
    },
    repositoryUrl: { type: String },
    repositoryOwner: { type: String },
    repositoryName: { type: String },
    branch: { type: String },
    workflowMetadata: { type: Schema.Types.Mixed },
    status: {
      type: String,
      enum: ['Draft', 'AI Generated', 'User Edited', 'Approved', 'Invoice Created', 'Escrow Created'],
      default: 'Draft',
      index: true,
    },
  },
  {
    timestamps: true,
    versionKey: false,
  }
);

// Compound index for versioning lookup
projectPlanSchema.index({ planId: 1, version: 1 }, { unique: true });

export const ProjectPlan: Model<IProjectPlan> = mongoose.model<IProjectPlan>('ProjectPlan', projectPlanSchema);
