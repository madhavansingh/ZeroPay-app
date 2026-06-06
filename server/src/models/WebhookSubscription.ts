import mongoose, { Document, Schema, Model } from 'mongoose';

export type WebhookEvent =
  | 'escrow.locked'
  | 'escrow.released'
  | 'escrow.disputed'
  | 'escrow.resolved'
  | 'invoice.created'
  | 'invoice.paid'
  | 'invoice.expired'
  | 'milestone.released';

export interface IWebhookSubscription extends Document {
  merchantId: mongoose.Types.ObjectId;
  apiKeyId: mongoose.Types.ObjectId;
  url: string;
  events: WebhookEvent[];
  secret: string;
  isActive: boolean;
  lastDeliveredAt?: Date;
  failureCount: number;
  createdAt: Date;
  updatedAt: Date;
}

const webhookSubscriptionSchema = new Schema<IWebhookSubscription>(
  {
    merchantId: {
      type: Schema.Types.ObjectId,
      ref: 'Merchant',
      required: true,
      index: true,
    },
    apiKeyId: {
      type: Schema.Types.ObjectId,
      ref: 'ApiKey',
      required: true,
    },
    url: {
      type: String,
      required: true,
      match: /^https:\/\/.+/,
    },
    events: {
      type: [String],
      enum: [
        'escrow.locked', 'escrow.released', 'escrow.disputed', 'escrow.resolved',
        'invoice.created', 'invoice.paid', 'invoice.expired', 'milestone.released',
      ],
      required: true,
      validate: {
        validator: (v: string[]) => v.length >= 1,
        message: 'At least one event type is required',
      },
    },
    secret: {
      type: String,
      required: true,
    },
    isActive: {
      type: Boolean,
      default: true,
    },
    lastDeliveredAt: Date,
    failureCount: {
      type: Number,
      default: 0,
      min: 0,
    },
  },
  {
    timestamps: true,
    versionKey: false,
  }
);

webhookSubscriptionSchema.index({ merchantId: 1, isActive: 1 });

export const WebhookSubscription: Model<IWebhookSubscription> = mongoose.model<IWebhookSubscription>(
  'WebhookSubscription',
  webhookSubscriptionSchema
);
