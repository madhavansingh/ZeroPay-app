import mongoose, { Document, Schema, Model } from 'mongoose';
import { nanoid } from 'nanoid';

export type EntryType = 'debit' | 'credit';

export interface ILedgerEntry {
  accountId: string;                 // 'merchant:{id}' | 'customer:{id}' | 'platform:treasury' | 'escrow:contract'
  type: EntryType;
  amountLovelace: number;            // Integer absolute Lovelace (Cardano)
  amountPaise: number;               // Integer absolute Paise (INR cents equivalent)
}

export interface ILedgerTransaction extends Document {
  ledgerTxId: string;
  invoiceId: string;
  createdAt: Date;
  entries: ILedgerEntry[];
}

const ledgerEntrySchema = new Schema<ILedgerEntry>(
  {
    accountId: { type: String, required: true, index: true },
    type: { type: String, enum: ['debit', 'credit'], required: true },
    amountLovelace: { type: Number, required: true, min: 0 },
    amountPaise: { type: Number, required: true, min: 0 },
  },
  { _id: false }
);

const ledgerTransactionSchema = new Schema<ILedgerTransaction>(
  {
    ledgerTxId: { type: String, default: () => `LT-${nanoid(10)}`, unique: true, required: true },
    invoiceId: { type: String, required: true, index: true },
    createdAt: { type: Date, default: Date.now, required: true, index: true },
    entries: { type: [ledgerEntrySchema], required: true, validate: [
      {
        validator: (val: ILedgerEntry[]) => val.length >= 2,
        message: 'Double-entry transaction must have at least 2 entries'
      },
      {
        validator: function(val: ILedgerEntry[]) {
          let totalDebits = 0;
          let totalCredits = 0;
          for (const entry of val) {
            const amount = Math.round(entry.amountLovelace);
            if (entry.type === 'debit') totalDebits += amount;
            else totalCredits += amount;
          }
          return totalDebits === totalCredits;
        },
        message: 'Double-entry Lovelace mismatch: debits do not equal credits'
      },
      {
        validator: function(val: ILedgerEntry[]) {
          let totalDebits = 0;
          let totalCredits = 0;
          for (const entry of val) {
            const amount = Math.round(entry.amountPaise);
            if (entry.type === 'debit') totalDebits += amount;
            else totalCredits += amount;
          }
          return totalDebits === totalCredits;
        },
        message: 'Double-entry Paise mismatch: debits do not equal credits'
      }
    ] },
  },
  {
    timestamps: false,
    versionKey: false,
  }
);

// Ledger entries are immutable (no updates/deletes permitted to maintain complete ledger transparency)
ledgerTransactionSchema.pre('save', function (next) {
  if (!this.isNew) {
    return next(new Error('Immutable Ledger Error: cannot update or modify finalized bookkeeping transactions.'));
  }
  next();
});

export const LedgerTransaction: Model<ILedgerTransaction> = mongoose.model<ILedgerTransaction>(
  'LedgerTransaction',
  ledgerTransactionSchema
);
