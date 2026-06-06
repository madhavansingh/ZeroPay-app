import mongoose, { Document, Schema, Model } from 'mongoose';

export type VerdictStatus = 'pending' | 'auto_queued' | 'accepted' | 'rejected' | 'executed';

export interface IDisputeVerdict extends Document {
  invoiceId: string;
  projectPlanId?: string;
  merchantSplitPercent: number;
  customerSplitPercent: number;
  confidence: number;
  reasoning: string;
  keyClaims: string[];
  autoExecAt?: Date;
  status: VerdictStatus;
  executedTxHash?: string;
  humanReviewRequired: boolean;
  reviewedBy?: mongoose.Types.ObjectId;
  assignedJurors?: mongoose.Types.ObjectId[];
  createdAt: Date;
  updatedAt: Date;
}

const disputeVerdictSchema = new Schema<IDisputeVerdict>(
  {
    invoiceId: {
      type: String,
      required: true,
      unique: true,
      immutable: true,
      index: true,
    },
    projectPlanId: {
      type: String,
      index: true,
      sparse: true,
    },
    merchantSplitPercent: {
      type: Number,
      required: true,
      min: 0,
      max: 100,
    },
    customerSplitPercent: {
      type: Number,
      required: true,
      min: 0,
      max: 100,
    },
    confidence: {
      type: Number,
      required: true,
      min: 0,
      max: 1,
    },
    reasoning: {
      type: String,
      required: true,
    },
    keyClaims: {
      type: [String],
      default: [],
    },
    autoExecAt: Date,
    status: {
      type: String,
      enum: ['pending', 'auto_queued', 'accepted', 'rejected', 'executed'],
      default: 'pending',
    },
    executedTxHash: String,
    humanReviewRequired: {
      type: Boolean,
      default: false,
    },
    reviewedBy: {
      type: Schema.Types.ObjectId,
      ref: 'User',
    },
    assignedJurors: {
      type: [Schema.Types.ObjectId],
      ref: 'User',
      default: [],
    },
  },
  {
    timestamps: true,
    versionKey: false,
  }
);

disputeVerdictSchema.index({ status: 1, autoExecAt: 1 });

// Pre-save validation: splits must sum to 100
disputeVerdictSchema.pre('save', function (next) {
  if (this.merchantSplitPercent + this.customerSplitPercent !== 100) {
    next(new Error('merchantSplitPercent + customerSplitPercent must equal 100'));
  } else {
    next();
  }
});

export const DisputeVerdict: Model<IDisputeVerdict> = mongoose.model<IDisputeVerdict>('DisputeVerdict', disputeVerdictSchema);
