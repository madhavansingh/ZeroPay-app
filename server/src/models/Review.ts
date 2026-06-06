import mongoose, { Document, Schema, Model } from 'mongoose';

export interface IReview extends Document {
  invoiceId: string;
  merchantId: mongoose.Types.ObjectId;
  customerId: mongoose.Types.ObjectId;
  productId?: mongoose.Types.ObjectId;
  rating: number;
  body?: string;
  isVerified: boolean;
  createdAt: Date;
}

const reviewSchema = new Schema<IReview>(
  {
    invoiceId: {
      type: String,
      required: true,
      unique: true,
      immutable: true,
      index: true,
    },
    merchantId: {
      type: Schema.Types.ObjectId,
      ref: 'Merchant',
      required: true,
      index: true,
    },
    customerId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    productId: {
      type: Schema.Types.ObjectId,
      ref: 'Product',
    },
    rating: {
      type: Number,
      required: true,
      min: 1,
      max: 5,
    },
    body: {
      type: String,
      maxlength: 400,
      trim: true,
    },
    isVerified: {
      type: Boolean,
      default: false,
    },
  },
  {
    timestamps: { createdAt: true, updatedAt: false },
    versionKey: false,
  }
);

reviewSchema.index({ merchantId: 1, isVerified: 1 });

export const Review: Model<IReview> = mongoose.model<IReview>('Review', reviewSchema);
