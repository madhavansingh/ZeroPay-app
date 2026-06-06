import mongoose, { Document, Schema, Model } from 'mongoose';

export interface IWebhookDeliveryLog extends Document {
  webhookSubscriptionId: mongoose.Types.ObjectId;
  event: string;
  url: string;
  payload: Record<string, unknown>;
  statusCode?: number;
  latencyMs?: number;
  responseBody?: string;
  error?: string;
  attemptNumber: number;
  success: boolean;
  createdAt: Date;
}

const webhookDeliveryLogSchema = new Schema<IWebhookDeliveryLog>(
  {
    webhookSubscriptionId: {
      type: Schema.Types.ObjectId,
      ref: 'WebhookSubscription',
      required: true,
      index: true,
    },
    event: { type: String, required: true },
    url: { type: String, required: true },
    payload: { type: Schema.Types.Map, of: Schema.Types.Mixed, required: true },
    statusCode: Number,
    latencyMs: Number,
    responseBody: String,
    error: String,
    attemptNumber: { type: Number, required: true },
    success: { type: Boolean, required: true, index: true },
  },
  {
    timestamps: { createdAt: true, updatedAt: false },
    versionKey: false,
  }
);

export const WebhookDeliveryLog: Model<IWebhookDeliveryLog> = mongoose.model<IWebhookDeliveryLog>(
  'WebhookDeliveryLog',
  webhookDeliveryLogSchema
);
