import mongoose, { Document, Schema, Model } from 'mongoose';

export type ApiPermission = 'escrow:read' | 'escrow:write' | 'invoice:read' | 'invoice:write' | 'webhooks:write' | 'merchant:read' | '*';

export interface IApiKey extends Document {
  keyId: string;
  keyHash: string;
  merchantId: mongoose.Types.ObjectId;
  name: string;
  permissions: ApiPermission[];
  rateLimitTier: 'starter' | 'pro' | 'enterprise';
  requestCount: number;
  lastUsedAt?: Date;
  expiresAt?: Date;
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
}

const apiKeySchema = new Schema<IApiKey>(
  {
    keyId: {
      type: String,
      required: true,
      unique: true,
      immutable: true,
      index: true,
    },
    keyHash: {
      type: String,
      required: true,
      unique: true,
      index: true,
    },
    merchantId: {
      type: Schema.Types.ObjectId,
      ref: 'Merchant',
      required: true,
      index: true,
    },
    name: {
      type: String,
      required: true,
      minlength: 1,
      maxlength: 100,
      trim: true,
    },
    permissions: {
      type: [String],
      enum: ['escrow:read', 'escrow:write', 'invoice:read', 'invoice:write', 'webhooks:write', 'merchant:read', '*'],
      default: ['escrow:read', 'merchant:read'],
    },
    rateLimitTier: {
      type: String,
      enum: ['starter', 'pro', 'enterprise'],
      default: 'starter',
    },
    requestCount: {
      type: Number,
      default: 0,
      min: 0,
    },
    lastUsedAt: Date,
    expiresAt: Date,
    isActive: {
      type: Boolean,
      default: true,
    },
  },
  {
    timestamps: true,
    versionKey: false,
  }
);

apiKeySchema.index({ merchantId: 1, isActive: 1 });

export const ApiKey: Model<IApiKey> = mongoose.model<IApiKey>('ApiKey', apiKeySchema);
