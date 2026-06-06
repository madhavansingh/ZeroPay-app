import mongoose, { Document, Schema, Model } from 'mongoose';

export interface ITransaction extends Document {
  txHash: string;
  invoiceId: mongoose.Types.ObjectId;
  invoiceStringId: string;
  merchantId: mongoose.Types.ObjectId;
  status: 'submitted' | 'confirming' | 'confirmed' | 'failed';
  amountLovelaceExpected: number;
  amountLovelaceVerified?: number;
  verificationResult?: 'amount-matched' | 'amount-mismatch' | 'address-mismatch';
  networkConfirmations: number;
  blockHeight?: number;
  blockHash?: string;
  slot?: number;
  pollingAttempts: number;
  lastPolledAt?: Date;
  confirmedAt?: Date;
  failureReason?: string;
  createdAt: Date;
  updatedAt: Date;
}

const transactionSchema = new Schema<ITransaction>(
  {
    txHash: {
      type: String,
      required: true,
      unique: true,
      immutable: true,
      index: true,
      match: /^[a-f0-9]{64}$/,
    },
    invoiceId: {
      type: Schema.Types.ObjectId,
      ref: 'Invoice',
      required: true,
      index: true,
    },
    invoiceStringId: {
      type: String,
      required: true,
    },
    merchantId: {
      type: Schema.Types.ObjectId,
      ref: 'Merchant',
      required: true,
      index: true,
    },
    status: {
      type: String,
      enum: ['submitted', 'confirming', 'confirmed', 'failed'],
      default: 'submitted',
      index: true,
    },
    amountLovelaceExpected: {
      type: Number,
      required: true,
    },
    amountLovelaceVerified: Number,
    verificationResult: {
      type: String,
      enum: ['amount-matched', 'amount-mismatch', 'address-mismatch'],
    },
    networkConfirmations: {
      type: Number,
      default: 0,
    },
    blockHeight: Number,
    blockHash: String,
    slot: Number,
    pollingAttempts: {
      type: Number,
      default: 0,
    },
    lastPolledAt: Date,
    confirmedAt: Date,
    failureReason: String,
  },
  {
    timestamps: true,
    versionKey: false,
  }
);

transactionSchema.index({ status: 1, createdAt: -1 });
transactionSchema.index({ merchantId: 1, status: 1, createdAt: -1 });

export const Transaction: Model<ITransaction> = mongoose.model<ITransaction>(
  'Transaction',
  transactionSchema
);
