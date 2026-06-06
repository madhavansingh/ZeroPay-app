import mongoose, { Document, Schema, Model } from 'mongoose';
import type { UserRole, OnboardingStep } from '@zeropay/shared-types';

export interface IUser extends Document {
  firebaseUid: string;
  phone?: string;
  displayName: string;
  role: UserRole;
  walletAddress?: string;
  walletProvider?: string;
  stakeAddress?: string;
  fcmToken?: string;
  notificationPreferences: {
    paymentReceived: boolean;
    paymentConfirmed: boolean;
    invoiceExpired: boolean;
    escrowUpdates: boolean;
    disputeAlerts: boolean;
    milestoneNotifications: boolean;
    channels: ('push' | 'email')[];
  };
  onboardingStep: OnboardingStep;
  createdAt: Date;
  updatedAt: Date;
}

const userSchema = new Schema<IUser>(
  {
    firebaseUid: {
      type: String,
      required: true,
      unique: true,
      immutable: true,
      index: true,
    },
    phone: {
      type: String,
      sparse: true,
      match: /^\+[1-9]\d{6,14}$/,
    },
    displayName: {
      type: String,
      required: true,
      default: 'ZeroPay User',
      minlength: 1,
      maxlength: 60,
      trim: true,
    },
    role: {
      type: String,
      enum: ['customer', 'merchant', 'both', 'admin'],
      required: true,
      default: 'customer',
    },
    walletAddress: {
      type: String,
      sparse: true,
      unique: true,
      match: /^addr(_test)?1[a-z0-9]+$/,
    },
    walletProvider: {
      type: String,
      trim: true,
    },
    stakeAddress: {
      type: String,
      sparse: true,
    },
    fcmToken: {
      type: String,
    },
    notificationPreferences: {
      paymentReceived: { type: Boolean, default: true },
      paymentConfirmed: { type: Boolean, default: true },
      invoiceExpired: { type: Boolean, default: false },
      escrowUpdates: { type: Boolean, default: true },
      disputeAlerts: { type: Boolean, default: true },
      milestoneNotifications: { type: Boolean, default: true },
      channels: { type: [String], enum: ['push', 'email'], default: ['push'] },
    },
    onboardingStep: {
      type: String,
      enum: ['new', 'role-selected', 'shop-complete', 'wallet-complete', 'complete'],
      default: 'new',
    },
  },
  {
    timestamps: true,
    versionKey: false,
  }
);

export const User: Model<IUser> = mongoose.model<IUser>('User', userSchema);
