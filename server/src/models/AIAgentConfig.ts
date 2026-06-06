import mongoose, { Document, Schema, Model } from 'mongoose';

export interface IAIAgentConfig extends Document {
  merchantId: mongoose.Types.ObjectId;
  negotiationEnabled: boolean;
  minDiscountPct: number;       // e.g. 5 means max 5% discount
  autoAcceptThresholdPct: number; // e.g. 2 means auto-accept if within 2%
  negotiationStyle: 'friendly' | 'firm' | 'aggressive';
  updatedAt: Date;
}

const aiAgentConfigSchema = new Schema<IAIAgentConfig>(
  {
    merchantId: {
      type: Schema.Types.ObjectId,
      ref: 'Merchant',
      required: true,
      unique: true,
      index: true,
    },
    negotiationEnabled: {
      type: Boolean,
      default: false,
    },
    minDiscountPct: {
      type: Number,
      default: 10, // Default max 10% discount
      min: 0,
      max: 50,
    },
    autoAcceptThresholdPct: {
      type: Number,
      default: 3, // Auto-accept if customer requests <= 3% discount
      min: 0,
      max: 20,
    },
    negotiationStyle: {
      type: String,
      enum: ['friendly', 'firm', 'aggressive'],
      default: 'friendly',
    },
  },
  {
    timestamps: { createdAt: false, updatedAt: true },
    versionKey: false,
  }
);

export const AIAgentConfig: Model<IAIAgentConfig> = mongoose.model<IAIAgentConfig>(
  'AIAgentConfig',
  aiAgentConfigSchema
);
