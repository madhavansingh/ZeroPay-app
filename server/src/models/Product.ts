import mongoose, { Document, Schema, Model } from 'mongoose';

export type ProductCategory = 'digital' | 'physical' | 'service';

export interface IProduct extends Document {
  merchantId: mongoose.Types.ObjectId;
  productId: string;
  title: string;
  description: string;
  priceLovelace: number;
  priceINR?: number;
  category: ProductCategory;
  isDigital: boolean;
  ipfsHash?: string;
  inventory?: number;
  images: string[];
  tags: string[];
  isActive: boolean;
  totalSold: number;
  rating?: number;
  createdAt: Date;
  updatedAt: Date;
}

const productSchema = new Schema<IProduct>(
  {
    merchantId: {
      type: Schema.Types.ObjectId,
      ref: 'Merchant',
      required: true,
      index: true,
    },
    productId: {
      type: String,
      required: true,
      unique: true,
      immutable: true,
      index: true,
    },
    title: {
      type: String,
      required: true,
      minlength: 1,
      maxlength: 80,
      trim: true,
    },
    description: {
      type: String,
      required: true,
      maxlength: 1000,
      trim: true,
    },
    priceLovelace: {
      type: Number,
      required: true,
      min: 1_000_000, // minimum 1 ADA
    },
    priceINR: {
      type: Number,
      min: 0,
    },
    category: {
      type: String,
      enum: ['digital', 'physical', 'service'],
      required: true,
    },
    isDigital: {
      type: Boolean,
      default: false,
    },
    ipfsHash: {
      type: String,
      trim: true,
    },
    inventory: {
      type: Number,
      min: 0,
    },
    images: {
      type: [String],
      default: [],
      validate: {
        validator: (v: string[]) => v.length <= 5,
        message: 'Maximum 5 images allowed',
      },
    },
    tags: {
      type: [String],
      default: [],
      validate: {
        validator: (v: string[]) => v.length <= 10,
        message: 'Maximum 10 tags allowed',
      },
    },
    isActive: {
      type: Boolean,
      default: true,
    },
    totalSold: {
      type: Number,
      default: 0,
      min: 0,
    },
    rating: {
      type: Number,
      min: 0,
      max: 5,
    },
  },
  {
    timestamps: true,
    versionKey: false,
  }
);

productSchema.index({ merchantId: 1, isActive: 1, category: 1 });
productSchema.index({ title: 'text', description: 'text', tags: 'text' });

export const Product: Model<IProduct> = mongoose.model<IProduct>('Product', productSchema);
