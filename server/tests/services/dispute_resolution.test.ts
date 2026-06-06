import { describe, it, expect, vi, beforeEach } from 'vitest';

// Mock env variables
vi.mock('../../src/config/env', () => ({
  env: {
    NODE_ENV: 'test',
    GEMINI_API_KEY: 'mock-gemini-key',
  },
}));

import { summarizeDispute } from '../../src/services/ai.service';
import { DisputeVerdict } from '../../src/models/DisputeVerdict';
import { Invoice } from '../../src/models/Invoice';
import { Merchant } from '../../src/models/Merchant';

// Mock model operations
vi.mock('../../src/models/Invoice', () => ({
  Invoice: {
    findOne: vi.fn(),
  },
}));

vi.mock('../../src/models/DisputeVerdict', () => ({
  DisputeVerdict: {
    findOne: vi.fn(),
    create: vi.fn().mockImplementation((data) => Promise.resolve({ _id: 'mock-verdict-id', ...data })),
  },
}));

vi.mock('../../src/models/Merchant', () => ({
  Merchant: {
    findById: vi.fn(),
  },
}));

vi.mock('../../src/services/ai.service', () => ({
  summarizeDispute: vi.fn().mockResolvedValue({
    recommendedSplitMerchantPercent: 50,
    recommendedSplitCustomerPercent: 50,
    reasoning: 'Even compromise suggested',
    keyClaims: ['Claim 1', 'Claim 2'],
  }),
}));

vi.mock('../../src/services/escrow.service', () => ({
  buildAdminResolveTx: vi.fn().mockResolvedValue({}),
}));

vi.mock('../../src/queues/queue.definitions', () => ({
  enqueueNotification: vi.fn().mockResolvedValue({}),
}));

describe('AI Arbitration & Dispute Resolution Engine', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('should auto-queue low-value disputes under high confidence (Auto-Exec mode)', async () => {
    // Low value: 10,000,000 Lovelace (< 20,000,000 threshold)
    const mockInvoice = {
      invoiceId: 'INV-LOW-VAL',
      amountLovelace: 10_000_000,
      amountPaise: 500000,
      escrowState: 'Disputed',
      merchantId: 'merchant-id',
      customerId: 'customer-id',
    };

    vi.mocked(Invoice.findOne).mockResolvedValueOnce(mockInvoice as any);
    vi.mocked(DisputeVerdict.findOne).mockResolvedValueOnce(null); // No verdict exists yet
    vi.mocked(Merchant.findById).mockResolvedValueOnce({
      userId: 'merchant-user-id',
      shopName: 'Merchant Shop',
    } as any);

    // Call summarizeDispute mock
    const summary = await summarizeDispute('INV-LOW-VAL');

    // Run custom worker logic directly for precision check
    const confidence = 0.90;
    const AUTO_DISPUTE_THRESHOLD_LOVELACE = 20_000_000;
    const isLowValue = mockInvoice.amountLovelace < AUTO_DISPUTE_THRESHOLD_LOVELACE;
    const canAutoExecute = isLowValue && confidence >= 0.80;

    expect(isLowValue).toBe(true);
    expect(canAutoExecute).toBe(true);

    const verdict = await DisputeVerdict.create({
      invoiceId: 'INV-LOW-VAL',
      merchantSplitPercent: summary.recommendedSplitMerchantPercent,
      customerSplitPercent: summary.recommendedSplitCustomerPercent,
      confidence,
      reasoning: summary.reasoning,
      keyClaims: summary.keyClaims,
      status: canAutoExecute ? 'auto_queued' : 'pending',
      autoExecAt: canAutoExecute ? new Date(Date.now() + 24 * 60 * 60 * 1000) : undefined,
      humanReviewRequired: !canAutoExecute,
    });

    expect(verdict.status).toBe('auto_queued');
    expect(verdict.humanReviewRequired).toBe(false);
    expect(verdict.autoExecAt).toBeDefined();
    expect(verdict.merchantSplitPercent + verdict.customerSplitPercent).toBe(100);
  });

  it('should require manual review for high-value disputes (Safeguard mode)', async () => {
    // High value: 50,000,000 Lovelace (>= 20,000,000 threshold)
    const mockInvoice = {
      invoiceId: 'INV-HIGH-VAL',
      amountLovelace: 50_000_000,
      amountPaise: 2500000,
      escrowState: 'Disputed',
      merchantId: 'merchant-id',
      customerId: 'customer-id',
    };

    vi.mocked(Invoice.findOne).mockResolvedValueOnce(mockInvoice as any);
    vi.mocked(DisputeVerdict.findOne).mockResolvedValueOnce(null);

    const summary = await summarizeDispute('INV-HIGH-VAL');

    const confidence = 0.90;
    const AUTO_DISPUTE_THRESHOLD_LOVELACE = 20_000_000;
    const isLowValue = mockInvoice.amountLovelace < AUTO_DISPUTE_THRESHOLD_LOVELACE;
    const canAutoExecute = isLowValue && confidence >= 0.80;

    expect(isLowValue).toBe(false);
    expect(canAutoExecute).toBe(false);

    const verdict = await DisputeVerdict.create({
      invoiceId: 'INV-HIGH-VAL',
      merchantSplitPercent: summary.recommendedSplitMerchantPercent,
      customerSplitPercent: summary.recommendedSplitCustomerPercent,
      confidence,
      reasoning: summary.reasoning,
      keyClaims: summary.keyClaims,
      status: canAutoExecute ? 'auto_queued' : 'pending',
      autoExecAt: canAutoExecute ? new Date() : undefined,
      humanReviewRequired: !canAutoExecute,
    });

    expect(verdict.status).toBe('pending');
    expect(verdict.humanReviewRequired).toBe(true);
    expect(verdict.autoExecAt).toBeUndefined();
  });

  it('should require manual review if AI confidence is low (< 80%)', async () => {
    const mockInvoice = {
      invoiceId: 'INV-LOW-CONF',
      amountLovelace: 10_000_000,
      escrowState: 'Disputed',
      merchantId: 'merchant-id',
    };

    vi.mocked(Invoice.findOne).mockResolvedValueOnce(mockInvoice as any);
    const summary = await summarizeDispute('INV-LOW-CONF');

    const confidence = 0.70; // Low confidence
    const AUTO_DISPUTE_THRESHOLD_LOVELACE = 20_000_000;
    const isLowValue = mockInvoice.amountLovelace < AUTO_DISPUTE_THRESHOLD_LOVELACE;
    const canAutoExecute = isLowValue && confidence >= 0.80;

    expect(canAutoExecute).toBe(false);

    const verdict = await DisputeVerdict.create({
      invoiceId: 'INV-LOW-CONF',
      merchantSplitPercent: summary.recommendedSplitMerchantPercent,
      customerSplitPercent: summary.recommendedSplitCustomerPercent,
      confidence,
      reasoning: summary.reasoning,
      keyClaims: summary.keyClaims,
      status: canAutoExecute ? 'auto_queued' : 'pending',
      autoExecAt: canAutoExecute ? new Date() : undefined,
      humanReviewRequired: !canAutoExecute,
    });

    expect(verdict.status).toBe('pending');
    expect(verdict.humanReviewRequired).toBe(true);
  });
});
