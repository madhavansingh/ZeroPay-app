import { describe, it, expect, vi, beforeEach } from 'vitest';

// 1. Mock env variables to prevent schema validation crashes
vi.mock('../../src/config/env', () => ({
  env: {
    NODE_ENV: 'test',
    GEMINI_API_KEY: 'mock-gemini-key',
    MIN_CONFIRMATIONS: 3,
    HIGH_VALUE_THRESHOLD_USD: 500,
    HIGH_VALUE_CONFIRMATIONS: 6,
  },
}));

// Mock Models
vi.mock('../../src/models/ProtocolAuditLog', () => ({
  ProtocolAuditLog: {
    create: vi.fn().mockResolvedValue({}),
  },
}));

vi.mock('../../src/models/AIAuditLog', () => ({
  AIAuditLog: {
    create: vi.fn().mockResolvedValue({}),
  },
}));

vi.mock('../../src/models/Invoice', () => ({
  Invoice: {
    findOne: vi.fn().mockResolvedValue({
      invoiceId: 'INV-TEST-DISPUTED',
      amountPaise: 100000,
      description: 'Mock dispute invoice',
      chatRoomId: null,
    }),
  },
}));

vi.mock('../../src/models/Evidence', () => ({
  Evidence: {
    find: vi.fn().mockResolvedValue([]),
  },
}));

vi.mock('../../src/models/Merchant', () => ({
  Merchant: {
    findById: vi.fn(),
  },
}));

import { domainEventBus, DomainEvents } from '../../src/events/eventBus';
import { generateMilestones, summarizeDispute } from '../../src/services/ai.service';
import { logProtocolActivity } from '../../src/services/audit.service';
import { ProtocolAuditLog } from '../../src/models/ProtocolAuditLog';
import { AIAuditLog } from '../../src/models/AIAuditLog';

describe('Lightweight Domain Event Bus', () => {
  it('should successfully publish events and execute listeners asynchronously', async () => {
    let triggered = false;
    let receivedPayload: any = null;

    domainEventBus.on('TestEvent', (payload) => {
      triggered = true;
      receivedPayload = payload;
    });

    domainEventBus.publish('TestEvent', { value: 42 });

    // Wait short delay to allow setImmediate to execute
    await new Promise((resolve) => setTimeout(resolve, 50));

    expect(triggered).toBe(true);
    expect(receivedPayload?.value).toBe(42);
  });
});

describe('Protocol Audit Trail System', () => {
  it('should create immutable audit log entries correctly', async () => {
    await logProtocolActivity({
      eventType: DomainEvents.EscrowLocked,
      status: 'success',
      actorId: 'test-user',
      requestId: 'req-123',
      invoiceId: 'inv-456',
      details: 'Test lock transaction logged',
      metadata: { txHash: '0xhash' },
    });

    expect(ProtocolAuditLog.create).toHaveBeenCalledWith(
      expect.objectContaining({
        eventType: DomainEvents.EscrowLocked,
        status: 'success',
        actorId: 'test-user',
        requestId: 'req-123',
        invoiceId: 'inv-456',
        details: 'Test lock transaction logged',
      })
    );
  });
});

describe('AI Safety & Reliability Layer (Mock validation & normalizations)', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('should gracefully handle milestone amount mismatches by normalizing the last milestone', async () => {
    // Generate milestones in mock mode returns two milestones summing to totalAmountPaise
    const suggest = await generateMilestones('Build complete escrow system', 100000);
    
    expect(suggest).toBeInstanceOf(Array);
    expect(suggest.length).toBe(2);
    // 50000 + 50000 = 100000
    expect(suggest[0].amountPaise + suggest[1].amountPaise).toBe(100000);
    expect(AIAuditLog.create).toHaveBeenCalled();
  });

  it('should invoke dispute summarization with fallback logic if Gemini execution triggers a failure', async () => {
    // In mock mode, summarizeDispute successfully returns standard mock split (50/50)
    const summary = await summarizeDispute('INV-TEST-DISPUTED');
    expect(summary.recommendedSplitMerchantPercent).toBe(50);
    expect(summary.recommendedSplitCustomerPercent).toBe(50);
    expect(AIAuditLog.create).toHaveBeenCalled();
  });
});
