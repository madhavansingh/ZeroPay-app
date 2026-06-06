import mongoose, { Document, Schema, Model } from 'mongoose';

export type DeliveryStatus = 'pending' | 'delivered' | 'expired';

export interface IDigitalDelivery extends Document {
  invoiceId: string;
  productId: mongoose.Types.ObjectId;
  customerId: mongoose.Types.ObjectId;
  ipfsHash: string;
  signedUrl: string;
  expiresAt: Date;
  downloadCount: number;
  status: DeliveryStatus;
  createdAt: Date;
}

const digitalDeliverySchema = new Schema<IDigitalDelivery>(
  {
    invoiceId: {
      type: String,
      required: true,
      index: true,
    },
    productId: {
      type: Schema.Types.ObjectId,
      ref: 'Product',
      required: true,
    },
    customerId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    ipfsHash: {
      type: String,
      required: true,
    },
    signedUrl: {
      type: String,
      required: true,
    },
    expiresAt: {
      type: Date,
      required: true,
      index: true,
    },
    downloadCount: {
      type: Number,
      default: 0,
      min: 0,
    },
    status: {
      type: String,
      enum: ['pending', 'delivered', 'expired'],
      default: 'pending',
    },
  },
  {
    timestamps: { createdAt: true, updatedAt: false },
    versionKey: false,
  }
);

export const DigitalDelivery: Model<IDigitalDelivery> = mongoose.model<IDigitalDelivery>(
  'DigitalDelivery',
  digitalDeliverySchema
);
