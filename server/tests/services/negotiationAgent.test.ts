import { describe, it, expect, vi, beforeEach } from 'vitest';
import mongoose from 'mongoose';

// 1. Mock env variables to prevent schema validation crashes
vi.mock('../../src/config/env', () => ({
  env: {
    NODE_ENV: 'test',
    GEMINI_API_KEY: 'mock-key',
    UPSTASH_REDIS_TLS_URL: 'redis://localhost:6379',
  },
}));

// Mock logger
vi.mock('../../src/config/logger', () => ({
  logger: {
    info: vi.fn(),
    warn: vi.fn(),
    error: vi.fn(),
  },
}));

// Mock Firebase Realtime Database
const mockRefUpdate = vi.fn().mockResolvedValue({});
const mockRefOnce = vi.fn().mockResolvedValue({
  forEach: (cb: any) => {},
  val: () => ({}),
  exists: () => false,
});
vi.mock('../../src/config/firebase-admin', () => ({
  getFirebaseDatabase: () => ({
    ref: vi.fn().mockReturnValue({
      update: mockRefUpdate,
      once: mockRefOnce,
      limitToLast: vi.fn().mockReturnThis(),
    }),
  }),
}));

import { runNegotiationStep } from '../../src/services/agent/negotiationAgent';
import { Invoice } from '../../src/models/Invoice';
import { AIAgentConfig } from '../../src/models/AIAgentConfig';
import { AIAuditLog } from '../../src/models/AIAuditLog';

// Mock mongoose save
const mockSave = vi.fn().mockResolvedValue({});

vi.mock('../../src/models/Invoice', () => ({
  Invoice: {
    findOne: vi.fn(),
  },
}));

vi.mock('../../src/models/AIAgentConfig', () => ({
  AIAgentConfig: {
    findOne: vi.fn(),
  },
}));

vi.mock('../../src/models/AIAuditLog', () => ({
  AIAuditLog: {
    create: vi.fn().mockResolvedValue({}),
  },
}));

describe('Stateful AI Negotiation Agent Service (Sprint 2)', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('should reject negotiation if invoice status is not pending', async () => {
    const mockInvoice = {
      invoiceId: 'INV-123',
      status: 'confirmed',
    };
    vi.mocked(Invoice.findOne).mockResolvedValueOnce(mockInvoice as any);

    const result = await runNegotiationStep('INV-123', 'Give me a discount please');
    expect(result.responseMessage).toContain('already confirmed');
    expect(result.dealAgreed).toBe(false);
  });

  it('should return default message if negotiation is disabled for merchant', async () => {
    const mockInvoice = {
      invoiceId: 'INV-123',
      status: 'pending',
      merchantId: new mongoose.Types.ObjectId(),
      amountPaise: 10000,
      save: mockSave,
    };
    vi.mocked(Invoice.findOne).mockResolvedValueOnce(mockInvoice as any);
    vi.mocked(AIAgentConfig.findOne).mockResolvedValueOnce(null); // No config = disabled

    const result = await runNegotiationStep('INV-123', 'Give me a discount please');
    expect(result.responseMessage).toContain('negotiation is currently disabled');
    expect(result.dealAgreed).toBe(false);
  });

  it('should negotiate discount within bounds and update invoice price', async () => {
    const mockInvoice = {
      invoiceId: 'INV-123',
      status: 'pending',
      merchantId: new mongoose.Types.ObjectId(),
      amountPaise: 10000, // ₹100.00
      amountLovelace: 50000000, // 50 ADA
      adaInrRate: 2, // ₹2 per ADA
      description: 'Test Web Design',
      milestones: [
        { title: 'Milestone 1', amountLovelace: 25000000, status: 'pending' },
        { title: 'Milestone 2', amountLovelace: 25000000, status: 'pending' },
      ],
      save: mockSave,
    };
    vi.mocked(Invoice.findOne).mockResolvedValueOnce(mockInvoice as any);

    const mockConfig = {
      negotiationEnabled: true,
      minDiscountPct: 10, // Max 10% discount allowed
      negotiationStyle: 'friendly',
    };
    vi.mocked(AIAgentConfig.findOne).mockResolvedValueOnce(mockConfig as any);

    // Run negotiation step with customer message asking for discount
    const result = await runNegotiationStep('INV-123', 'Can I get a discount?');

    // In mock mode, a 5% discount is applied: ₹95.00 (9500 paise)
    expect(result.proposedPricePaise).toBe(9500);
    expect(mockInvoice.amountPaise).toBe(9500);
    expect(mockInvoice.amountLovelace).toBe(47500000); // 9500 paise / 100 = ₹95 / 2 = 47.5 ADA = 47500000 Lovelace
    expect(mockInvoice.milestones[0].amountLovelace).toBe(23750000);
    expect(mockInvoice.milestones[1].amountLovelace).toBe(23750000);
    expect(mockSave).toHaveBeenCalled();
    expect(AIAuditLog.create).toHaveBeenCalled();
  });

  it('should finalize deal and set dealAgreed to true when customer accepts', async () => {
    const mockInvoice = {
      invoiceId: 'INV-123',
      status: 'pending',
      merchantId: new mongoose.Types.ObjectId(),
      amountPaise: 9500,
      amountLovelace: 47500000,
      adaInrRate: 2,
      description: 'Test Web Design',
      save: mockSave,
    };
    vi.mocked(Invoice.findOne).mockResolvedValueOnce(mockInvoice as any);

    const mockConfig = {
      negotiationEnabled: true,
      minDiscountPct: 10,
      negotiationStyle: 'friendly',
    };
    vi.mocked(AIAgentConfig.findOne).mockResolvedValueOnce(mockConfig as any);

    const result = await runNegotiationStep('INV-123', 'I agree to the deal');

    expect(result.dealAgreed).toBe(true);
    expect(AIAuditLog.create).toHaveBeenCalled();
  });
});
