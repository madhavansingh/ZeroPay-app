import mongoose, { Document, Schema, Model } from 'mongoose';

export interface IEvidence extends Document {
  invoiceId: string;
  uploaderId: mongoose.Types.ObjectId;
  ipfsHash: string;
  fileName: string;
  mimeType: string;
  fileSize: number;
  createdAt: Date;
  updatedAt: Date;
}

const evidenceSchema = new Schema<IEvidence>(
  {
    invoiceId: {
      type: String,
      required: true,
      index: true,
    },
    uploaderId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    ipfsHash: {
      type: String,
      required: true,
      unique: true,
    },
    fileName: {
      type: String,
      required: true,
    },
    mimeType: {
      type: String,
      required: true,
    },
    fileSize: {
      type: Number,
      required: true,
    },
  },
  {
    timestamps: true,
    versionKey: false,
  }
);

export const Evidence: Model<IEvidence> = mongoose.model<IEvidence>('Evidence', evidenceSchema);
