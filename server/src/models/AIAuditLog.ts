import mongoose, { Document, Schema, Model } from 'mongoose';

export interface IAIAuditLog extends Document {
  timestamp: Date;
  action: 'generate-milestones' | 'summarize-dispute' | 'detect-anomaly';
  requestId?: string;
  invoiceId?: string;
  actorId: string;
  promptTemplate: string;
  inputData: any;
  rawResponse?: string;
  parsedResponse?: any;
  validationErrors?: any;
  confidenceScore?: number;
  latencyMs: number;
  status: 'success' | 'failure';
}

const aiAuditLogSchema = new Schema<IAIAuditLog>(
  {
    timestamp: { type: Date, default: Date.now, required: true },
    action: { type: String, required: true, index: true },
    requestId: { type: String, index: true },
    invoiceId: { type: String, index: true },
    actorId: { type: String, required: true, index: true },
    promptTemplate: { type: String, required: true },
    inputData: { type: Schema.Types.Mixed, required: true },
    rawResponse: { type: String },
    parsedResponse: { type: Schema.Types.Mixed },
    validationErrors: { type: Schema.Types.Mixed },
    confidenceScore: { type: Number },
    latencyMs: { type: Number, required: true },
    status: { type: String, enum: ['success', 'failure'], required: true },
  },
  {
    timestamps: false,
    versionKey: false,
  }
);

export const AIAuditLog: Model<IAIAuditLog> = mongoose.model<IAIAuditLog>('AIAuditLog', aiAuditLogSchema);
