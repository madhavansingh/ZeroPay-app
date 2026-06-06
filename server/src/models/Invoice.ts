import mongoose, { Document, Schema, Model } from 'mongoose';
import type { InvoiceStatus } from '@zeropay/shared-types';

export interface IMilestone {
  milestoneId?: string;
  title: string;
  description?: string;
  amountLovelace: number;
  status: 'pending' | 'released' | 'disputed';
  releasedAt?: Date;
}

export interface IInvoice extends Document {
  invoiceId: string;
  merchantId: mongoose.Types.ObjectId;
  merchantStringId: string;
  customerId?: mongoose.Types.ObjectId;
  productId?: mongoose.Types.ObjectId;
  chatRoomId?: string;
  description?: string;
  // Immutable snapshots — set once at creation
  amountPaise: number;
  originalAmountPaise?: number;
  amountLovelace: number;
  adaInrRate: number;
  paymentAddress: string;
  // Lifecycle
  status: InvoiceStatus;
  txHash?: string;
  expiresAt: Date;
  // Timestamps per transition
  submittedAt?: Date;
  confirmingAt?: Date;
  confirmedAt?: Date;
  settledAt?: Date;
  // Receipt
  receiptCid?: string;
  receiptPending?: boolean;
  // On-chain verification
  amountLovelaceVerified?: number;
  verificationResult?: 'amount-matched' | 'amount-mismatch' | 'address-mismatch';
  networkConfirmations?: number;
  // Escrow state machine fields
  escrowState: 'None' | 'Created' | 'PendingApproval' | 'Locked' | 'PartiallyReleased' | 'Released' | 'Refunded' | 'Disputed' | 'Resolved';
  milestones: IMilestone[];
  milestoneIndex: number;
  totalMilestones: number;
  isDisputed: boolean;
  agreementHash?: string; // IPFS CID of terms
  metadataHash?: string;
  contractVersion: number;
  projectPlanId?: string;
  escrowLockTxHash?: string;      // TX hash of the lock transaction
  escrowCustomerAddress?: string; // Customer bech32 address used for locking
  disputeTxHash?: string;         // TX hash of the dispute transaction
  resolutionTxHash?: string;      // TX hash of the admin resolution TX
  network?: 'cardano' | 'base';
  createdAt: Date;
  updatedAt: Date;
}

const invoiceSchema = new Schema<IInvoice>(
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
    merchantStringId: {
      type: String,
      required: true,
      index: true,
    },
    customerId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      sparse: true,
    },
    productId: {
      type: Schema.Types.ObjectId,
      ref: 'Product',
      sparse: true,
    },
    chatRoomId: {
      type: String,
      sparse: true,
    },
    projectPlanId: {
      type: String,
      index: true,
      sparse: true,
    },
    description: {
      type: String,
      maxlength: 100,
      trim: true,
    },
    // ── Immutable snapshot fields ──────────────────────────────────────────────
    amountPaise: {
      type: Number,
      required: true,
      min: 100, // minimum ₹1.00
      immutable: true,
    },
    originalAmountPaise: {
      type: Number,
    },
    amountLovelace: {
      type: Number,
      required: true,
      min: 1000000, // minimum 1 ADA
      immutable: true,
    },
    adaInrRate: {
      type: Number,
      required: true,
      immutable: true,
    },
    paymentAddress: {
      type: String,
      required: true,
      immutable: true,
      match: /^addr(_test)?1[a-z0-9]+$/,
    },
    // ── Lifecycle ──────────────────────────────────────────────────────────────
    status: {
      type: String,
      enum: ['pending', 'submitted', 'confirming', 'confirmed', 'settled', 'expired', 'failed'],
      default: 'pending',
      index: true,
    },
    txHash: {
      type: String,
      sparse: true,
      unique: true,
      match: /^[a-f0-9]{64}$/,
    },
    expiresAt: {
      type: Date,
      required: true,
      index: { expireAfterSeconds: 86400 }, // auto-cleanup after 24h post-expiry
    },
    submittedAt: Date,
    confirmingAt: Date,
    confirmedAt: Date,
    settledAt: Date,
    receiptCid: String,
    receiptPending: { type: Boolean, default: false },
    amountLovelaceVerified: Number,
    verificationResult: {
      type: String,
      enum: ['amount-matched', 'amount-mismatch', 'address-mismatch'],
    },
    networkConfirmations: Number,
    // Escrow state fields
    escrowState: {
      type: String,
      enum: ['None', 'Created', 'PendingApproval', 'Locked', 'PartiallyReleased', 'Released', 'Refunded', 'Disputed', 'Resolved'],
      default: 'None',
      index: true,
    },
    milestones: [
      {
        milestoneId: { type: String, sparse: true },
        title: { type: String, required: true },
        description: { type: String, default: '' },
        amountLovelace: { type: Number, required: true },
        status: { type: String, enum: ['pending', 'released', 'disputed'], default: 'pending' },
        releasedAt: Date,
      },
    ],
    milestoneIndex: { type: Number, default: 0 },
    totalMilestones: { type: Number, default: 0 },
    isDisputed: { type: Boolean, default: false },
    agreementHash: String,
    metadataHash: String,
    contractVersion: { type: Number, default: 1 },
    escrowLockTxHash: { type: String, sparse: true, match: /^[a-f0-9]{64}$/ },
    escrowCustomerAddress: { type: String, match: /^addr(_test)?1[a-z0-9]+$/ },
    disputeTxHash: { type: String, sparse: true, match: /^[a-f0-9]{64}$/ },
    resolutionTxHash: { type: String, sparse: true, match: /^[a-f0-9]{64}$/ },
    network: {
      type: String,
      enum: ['cardano', 'base'],
      default: 'cardano',
      index: true,
    },
  },
  {
    timestamps: true,
    versionKey: false,
  }
);

// Compound indexes for common queries
invoiceSchema.index({ merchantId: 1, status: 1, createdAt: -1 });
invoiceSchema.index({ merchantStringId: 1, status: 1, createdAt: -1 });
invoiceSchema.index({ status: 1, expiresAt: 1 }); // expiry worker
invoiceSchema.index({ status: 1, createdAt: -1 }); // admin queries
invoiceSchema.index({ merchantId: 1, createdAt: -1 }); // optimized recent transaction feed
invoiceSchema.index({ merchantId: 1, status: 1, settledAt: -1 }); // optimized 7-day aggregation window

// Prevent mutation of immutable snapshot fields after creation
invoiceSchema.pre('save', function (next) {
  if (!this.isNew && this.status !== 'pending') {
    const immutableFields = ['amountPaise', 'amountLovelace', 'adaInrRate', 'paymentAddress'] as const;
    for (const field of immutableFields) {
      if (this.isModified(field)) {
        return next(new Error(`Cannot modify immutable field: ${field}`));
      }
    }
  }

  // Verify escrowState transition validity on save
  if (this.isModified('escrowState')) {
    const from = this.modifiedPaths().includes('escrowState') ? (this as any)._originalEscrowState || 'None' : this.escrowState;
    if (!isValidTransition(from, this.escrowState)) {
      return next(new Error(`Invalid escrow state transition from "${from}" to "${this.escrowState}"`));
    }
  }
  next();
});

// Cache original escrowState to check transitions in pre-save hook
invoiceSchema.post('init', function (doc) {
  (doc as any)._originalEscrowState = doc.escrowState;
});

export type EscrowState = 'None' | 'Created' | 'PendingApproval' | 'Locked' | 'PartiallyReleased' | 'Released' | 'Refunded' | 'Disputed' | 'Resolved';

const VALID_TRANSITIONS: Record<EscrowState, EscrowState[]> = {
  None: ['Created', 'Locked'],
  Created: ['PendingApproval', 'Locked'],
  PendingApproval: ['Locked'],
  Locked: ['PartiallyReleased', 'Released', 'Disputed', 'Refunded'],
  PartiallyReleased: ['PartiallyReleased', 'Released', 'Disputed', 'Refunded'],
  Released: [],
  Refunded: [],
  Disputed: ['Resolved'],
  Resolved: [],
};

export function isValidTransition(from: EscrowState, to: EscrowState): boolean {
  if (from === to) return true;
  const allowed = VALID_TRANSITIONS[from];
  return allowed ? allowed.includes(to) : false;
}

export const Invoice: Model<IInvoice> = mongoose.model<IInvoice>('Invoice', invoiceSchema);
