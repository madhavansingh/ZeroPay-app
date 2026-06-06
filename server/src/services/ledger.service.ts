import { LedgerTransaction } from '../models/LedgerTransaction';
import { logger } from '../config/logger';

export class LedgerService {
  /**
   * Post double-entry records when a customer locks ADA/Escrow funds into the Plutus script contract.
   * Debits the customer's account and credits the script escrow account.
   */
  public static async recordLock(params: {
    invoiceId: string;
    customerId: string;
    amountLovelace: number;
    amountPaise: number;
  }): Promise<void> {
    const { invoiceId, customerId, amountLovelace, amountPaise } = params;

    try {
      await LedgerTransaction.create({
        invoiceId,
        entries: [
          {
            accountId: `customer:${customerId}`,
            type: 'debit',
            amountLovelace,
            amountPaise,
          },
          {
            accountId: 'escrow:contract',
            type: 'credit',
            amountLovelace,
            amountPaise,
          },
        ],
      });
      logger.info('[Ledger] Locked transaction posted successfully', { invoiceId, customerId });
    } catch (err: any) {
      logger.error('[Ledger] Failed to post Lock transaction', { invoiceId, error: err.message });
      throw err;
    }
  }

  /**
   * Post records when milestone or final funds are released from the escrow script.
   * Debits the script escrow account.
   * Credits the merchant account (total minus platform fee) and credits the platform treasury (fees).
   */
  public static async recordRelease(params: {
    invoiceId: string;
    merchantId: string;
    amountLovelace: number;          // Total released amount
    amountPaise: number;             // Total released paise
    feeLovelace: number;             // Deducted platform fee in Lovelace
    feePaise: number;                // Deducted platform fee in Paise
  }): Promise<void> {
    const { invoiceId, merchantId, amountLovelace, amountPaise, feeLovelace, feePaise } = params;

    const merchantLovelace = amountLovelace - feeLovelace;
    const merchantPaise = amountPaise - feePaise;

    try {
      await LedgerTransaction.create({
        invoiceId,
        entries: [
          {
            accountId: 'escrow:contract',
            type: 'debit',
            amountLovelace,
            amountPaise,
          },
          {
            accountId: `merchant:${merchantId}`,
            type: 'credit',
            amountLovelace: merchantLovelace,
            amountPaise: merchantPaise,
          },
          {
            accountId: 'platform:treasury',
            type: 'credit',
            amountLovelace: feeLovelace,
            amountPaise: feePaise,
          },
        ],
      });
      logger.info('[Ledger] Release transaction posted successfully', { invoiceId, merchantId });
    } catch (err: any) {
      logger.error('[Ledger] Failed to post Release transaction', { invoiceId, error: err.message });
      throw err;
    }
  }

  /**
   * Post double-entry records when funds are refunded back to the customer.
   * Debits the script escrow account and credits the customer's account.
   */
  public static async recordRefund(params: {
    invoiceId: string;
    customerId: string;
    amountLovelace: number;
    amountPaise: number;
  }): Promise<void> {
    const { invoiceId, customerId, amountLovelace, amountPaise } = params;

    try {
      await LedgerTransaction.create({
        invoiceId,
        entries: [
          {
            accountId: 'escrow:contract',
            type: 'debit',
            amountLovelace,
            amountPaise,
          },
          {
            accountId: `customer:${customerId}`,
            type: 'credit',
            amountLovelace,
            amountPaise,
          },
        ],
      });
      logger.info('[Ledger] Refund transaction posted successfully', { invoiceId, customerId });
    } catch (err: any) {
      logger.error('[Ledger] Failed to post Refund transaction', { invoiceId, error: err.message });
      throw err;
    }
  }
}
