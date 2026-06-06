import mongoose, { Document, Schema, Model } from 'mongoose';

export interface IJuror extends Document {
  userId: mongoose.Types.ObjectId;
  status: 'idle' | 'assigned' | 'suspended';
  stakedReputation: number;       // Amount of reputation/credits staked (e.g. 100)
  disputesResolvedCount: number;
  accuracyScore: number;          // Percent of times juror voted in consensus (0-100)
  createdAt: Date;
  updatedAt: Date;
}

const jurorSchema = new Schema<IJuror>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      unique: true,
      index: true,
    },
    status: {
      type: String,
      enum: ['idle', 'assigned', 'suspended'],
      default: 'idle',
      index: true,
    },
    stakedReputation: {
      type: Number,
      default: 100,
      min: 0,
    },
    disputesResolvedCount: {
      type: Number,
      default: 0,
      min: 0,
    },
    accuracyScore: {
      type: Number,
      default: 100, // starts at 100%
      min: 0,
      max: 100,
    },
  },
  {
    timestamps: true,
    versionKey: false,
  }
);

export const Juror: Model<IJuror> = mongoose.model<IJuror>('Juror', jurorSchema);
