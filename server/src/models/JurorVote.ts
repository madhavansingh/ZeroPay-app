import mongoose, { Document, Schema, Model } from 'mongoose';

export interface IJurorVote extends Document {
  disputeId: string; // references invoiceId
  jurorId: mongoose.Types.ObjectId; // references Juror document ID or user ID
  recommendedMerchantSplitPct: number; // e.g. 60
  recommendedCustomerSplitPct: number; // e.g. 40
  reasoning: string;
  votedAt: Date;
}

const jurorVoteSchema = new Schema<IJurorVote>(
  {
    disputeId: {
      type: String,
      required: true,
      index: true,
    },
    jurorId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    recommendedMerchantSplitPct: {
      type: Number,
      required: true,
      min: 0,
      max: 100,
    },
    recommendedCustomerSplitPct: {
      type: Number,
      required: true,
      min: 0,
      max: 100,
    },
    reasoning: {
      type: String,
      required: true,
      maxlength: 1000,
    },
    votedAt: {
      type: Date,
      default: Date.now,
    },
  },
  {
    versionKey: false,
  }
);

// Enforce unique voting: a juror can only vote once per dispute
jurorVoteSchema.index({ disputeId: 1, jurorId: 1 }, { unique: true });

export const JurorVote: Model<IJurorVote> = mongoose.model<IJurorVote>('JurorVote', jurorVoteSchema);
