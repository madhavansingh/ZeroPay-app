import mongoose, { Document, Schema, Model } from 'mongoose';
import type { MerchantCategory } from '@zeropay/shared-types';

export interface IMerchantLocation {
  city?: string;
  state?: string;
  country?: string;
}

export interface IMerchantSocialLinks {
  instagram?: string;
  twitter?: string;
  website?: string;
}

export interface IMerchant extends Document {
  userId: mongoose.Types.ObjectId;
  merchantId: string;
  shopName: string;
  category: MerchantCategory;
  description?: string;
  paymentAddress: string;
  invoiceExpiry: number;
  totalReceivedLovelace: number;
  totalOrders: number;
  reputationScore: number;
  escrowCompletionRate: number;
  milestoneFulfillmentRate: number;
  disputeCount: number;
  disputesWonCount: number;
  verifiedMerchantBadge: boolean;
  reliabilityTier: 'silver' | 'gold' | 'platinum' | 'unrated';
  isActive: boolean;
  // Phase 3 — Storefront fields
  slug?: string;
  profileImageUrl?: string;
  bannerImageUrl?: string;
  location?: IMerchantLocation;
  socialLinks?: IMerchantSocialLinks;
  isPublicStorefront: boolean;
  businessHours?: string;
  totalStorefrontViews: number;
  totalStorefrontConversions: number;
  createdAt: Date;
  updatedAt: Date;
}

const merchantSchema = new Schema<IMerchant>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      unique: true,
      immutable: true,
      index: true,
    },
    merchantId: {
      type: String,
      required: true,
      unique: true,
      immutable: true,
      index: true,
      match: /^MC-\d{4,6}$/,
    },
    shopName: {
      type: String,
      required: true,
      minlength: 2,
      maxlength: 50,
      trim: true,
    },
    category: {
      type: String,
      enum: ['food', 'retail', 'services', 'vendor', 'other'],
      required: true,
    },
    description: {
      type: String,
      maxlength: 200,
      trim: true,
    },
    paymentAddress: {
      type: String,
      required: true,
      index: true,
      match: /^addr(_test)?1[a-z0-9]+$/,
    },
    invoiceExpiry: {
      type: Number,
      required: true,
      default: 600,
      min: 300,
      max: 1800,
    },
    totalReceivedLovelace: {
      type: Number,
      default: 0,
      min: 0,
    },
    totalOrders: {
      type: Number,
      default: 0,
      min: 0,
    },
    reputationScore: {
      type: Number,
      default: 100,
      min: 0,
      max: 100,
    },
    escrowCompletionRate: {
      type: Number,
      default: 0,
      min: 0,
      max: 100,
    },
    milestoneFulfillmentRate: {
      type: Number,
      default: 0,
      min: 0,
      max: 100,
    },
    disputeCount: {
      type: Number,
      default: 0,
      min: 0,
    },
    disputesWonCount: {
      type: Number,
      default: 0,
      min: 0,
    },
    verifiedMerchantBadge: {
      type: Boolean,
      default: false,
    },
    reliabilityTier: {
      type: String,
      enum: ['silver', 'gold', 'platinum', 'unrated'],
      default: 'unrated',
    },
    isActive: {
      type: Boolean,
      default: true,
    },
    // ── Phase 3: Storefront fields ─────────────────────────────────────────────
    slug: {
      type: String,
      unique: true,
      sparse: true,
      lowercase: true,
      trim: true,
      match: /^[a-z0-9][a-z0-9-]{1,48}[a-z0-9]$/,
    },
    profileImageUrl: {
      type: String,
      trim: true,
    },
    bannerImageUrl: {
      type: String,
      trim: true,
    },
    location: {
      city: { type: String, trim: true, maxlength: 100 },
      state: { type: String, trim: true, maxlength: 100 },
      country: { type: String, trim: true, maxlength: 100 },
    },
    socialLinks: {
      instagram: { type: String, trim: true },
      twitter: { type: String, trim: true },
      website: { type: String, trim: true },
    },
    isPublicStorefront: {
      type: Boolean,
      default: false,
    },
    businessHours: {
      type: String,
      maxlength: 500,
      trim: true,
    },
    totalStorefrontViews: {
      type: Number,
      default: 0,
      min: 0,
    },
    totalStorefrontConversions: {
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

// Compound index for dashboard queries
merchantSchema.index({ userId: 1, isActive: 1 });
// Phase 3: Storefront discovery indexes
merchantSchema.index({ 'location.city': 1 });
merchantSchema.index({ isPublicStorefront: 1, reputationScore: -1 });

export const Merchant: Model<IMerchant> = mongoose.model<IMerchant>('Merchant', merchantSchema);
