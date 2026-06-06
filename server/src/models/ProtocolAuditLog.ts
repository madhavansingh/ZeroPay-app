import mongoose, { Document, Schema, Model } from 'mongoose';

export interface IProtocolAuditLog extends Document {
  timestamp: Date;
  eventType: string;
  status: 'success' | 'failure';
  actorId: string; // User ID or 'system'
  requestId?: string;
  invoiceId?: string;
  metadata: Record<string, any>;
  details: string;
}

const protocolAuditLogSchema = new Schema<IProtocolAuditLog>(
  {
    timestamp: { type: Date, default: Date.now, required: true },
    eventType: { type: String, required: true, index: true },
    status: { type: String, enum: ['success', 'failure'], required: true },
    actorId: { type: String, required: true, index: true },
    requestId: { type: String, index: true },
    invoiceId: { type: String, index: true },
    metadata: { type: Schema.Types.Mixed, default: {} },
    details: { type: String, required: true },
  },
  {
    timestamps: false,
    versionKey: false,
  }
);

// Enforce read-only constraint at mongoose schema level (no updates allowed)
protocolAuditLogSchema.pre('save', function (next) {
  if (!this.isNew) {
    return next(new Error('Cannot modify immutable protocol audit logs'));
  }
  next();
});

export const ProtocolAuditLog: Model<IProtocolAuditLog> = mongoose.model<IProtocolAuditLog>(
  'ProtocolAuditLog',
  protocolAuditLogSchema
);
