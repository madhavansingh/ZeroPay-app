import mongoose, { Document, Schema, Model } from 'mongoose';

export interface ITelemetryLog extends Document {
  type: 'event' | 'metric';
  name: string;
  value?: number;
  parameters?: Record<string, any>;
  timestamp: Date;
}

const telemetryLogSchema = new Schema<ITelemetryLog>(
  {
    type: {
      type: String,
      enum: ['event', 'metric'],
      required: true,
      index: true,
    },
    name: {
      type: String,
      required: true,
      index: true,
    },
    value: {
      type: Number,
    },
    parameters: {
      type: Schema.Types.Map,
      of: Schema.Types.Mixed,
    },
    timestamp: {
      type: Date,
      default: Date.now,
      required: true,
      index: true,
    },
  },
  {
    timestamps: false,
    versionKey: false,
  }
);

export const TelemetryLog: Model<ITelemetryLog> = mongoose.model<ITelemetryLog>('TelemetryLog', telemetryLogSchema);
