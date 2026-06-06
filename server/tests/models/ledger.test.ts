import { describe, it, expect, beforeEach } from 'vitest';
import mongoose from 'mongoose';
import { LedgerTransaction } from '../../src/models/LedgerTransaction';

describe('Immutable Double-Entry Ledger System', () => {
  beforeEach(async () => {
    // Clear ledger collections offline if Mongoose is connected
    if (mongoose.connection.readyState === 1) {
      await LedgerTransaction.deleteMany({});
    }
  });

  it('should allow saving valid, perfectly balanced double-entry transactions', async () => {
    const tx = new LedgerTransaction({
      invoiceId: 'INV-LEDGER-TEST-1',
      entries: [
        {
          accountId: 'customer:cust_123',
          type: 'debit',
          amountLovelace: 10_000_000,
          amountPaise: 40000,
        },
        {
          accountId: 'escrow:contract',
          type: 'credit',
          amountLovelace: 10_000_000,
          amountPaise: 40000,
        },
      ],
    });

    // Offline schema validation
    const valErr = tx.validateSync();
    expect(valErr).toBeUndefined();
    expect(tx.entries).toHaveLength(2);
  });

  it('should fail validation if debits and credits do not balance in Lovelace', async () => {
    const tx = new LedgerTransaction({
      invoiceId: 'INV-LEDGER-TEST-2',
      entries: [
        {
          accountId: 'customer:cust_123',
          type: 'debit',
          amountLovelace: 10_000_000, // Debiting 10 ADA
          amountPaise: 40000,
        },
        {
          accountId: 'escrow:contract',
          type: 'credit',
          amountLovelace: 9_000_000, // Crediting only 9 ADA - mismatch!
          amountPaise: 40000,
        },
      ],
    });

    const valErr = tx.validateSync();
    expect(valErr).toBeDefined();
    expect(valErr?.message).toContain('Double-entry Lovelace mismatch');
  });

  it('should fail validation if debits and credits do not balance in Paise', async () => {
    const tx = new LedgerTransaction({
      invoiceId: 'INV-LEDGER-TEST-3',
      entries: [
        {
          accountId: 'customer:cust_123',
          type: 'debit',
          amountLovelace: 10_000_000,
          amountPaise: 40000, // Debiting 40,000 Paise
        },
        {
          accountId: 'escrow:contract',
          type: 'credit',
          amountLovelace: 10_000_000,
          amountPaise: 38000, // Crediting only 38,000 Paise - mismatch!
        },
      ],
    });

    const valErr = tx.validateSync();
    expect(valErr).toBeDefined();
    expect(valErr?.message).toContain('Double-entry Paise mismatch');
  });

  it('should fail validation if there is only a single entry', async () => {
    const tx = new LedgerTransaction({
      invoiceId: 'INV-LEDGER-TEST-4',
      entries: [
        {
          accountId: 'customer:cust_123',
          type: 'debit',
          amountLovelace: 10_000_000,
          amountPaise: 40000,
        },
      ],
    });

    const valErr = tx.validateSync();
    expect(valErr).toBeDefined();
    expect(valErr?.message).toContain('at least 2 entries');
  });
});
