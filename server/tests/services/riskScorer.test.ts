import { describe, it, expect, vi, beforeEach } from 'vitest';

vi.mock('../../src/config/env', () => ({
  env: {
    NODE_ENV: 'test',
    GEMINI_API_KEY: 'mock-gemini-key',
    MIN_CONFIRMATIONS: 3,
    HIGH_VALUE_THRESHOLD_USD: 500,
    HIGH_VALUE_CONFIRMATIONS: 6,
  },
}));

// Mock Mongoose models to prevent buffering timeouts
vi.mock('../../src/models/Merchant', () => ({
  Merchant: {
    findById: vi.fn().mockResolvedValue({
      disputeRate: 0,
      totalOrders: 5,
    }),
  },
}));

vi.mock('../../src/models/Invoice', () => ({
  Invoice: {
    aggregate: vi.fn().mockResolvedValue([]),
  },
}));

import { RiskScorer } from '../../src/services/riskScorer';
import { upstashRedis } from '../../src/config/redis';
import { Merchant } from '../../src/models/Merchant';
import { Invoice } from '../../src/models/Invoice';

// Mock Redis connection methods to operate safely in memory/mock states
vi.mock('../../src/config/redis', () => {
  const store = new Map<string, string[]>();
  return {
    upstashRedis: {
      zremrangebyscore: vi.fn().mockResolvedValue(0),
      zadd: vi.fn().mockImplementation((key: string, data: { member: string }) => {
        const arr = store.get(key) || [];
        arr.push(data.member);
        store.set(key, arr);
        return 1;
      }),
      zcard: vi.fn().mockImplementation((key: string) => {
        return (store.get(key) || []).length;
      }),
      zrange: vi.fn().mockImplementation((key: string) => {
        return store.get(key) || [];
      }),
      expire: vi.fn().mockResolvedValue(true),
    },
  };
});

describe('AI & Redis Sliding-Window Transaction Risk Scorer', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('should track low-velocity healthy wallets with minimal base score and approve suggestions', async () => {
    const profile = await RiskScorer.analyzeTransaction({
      walletAddress: 'addr_test1qrr2cldldlcustomer',
      amountLovelace: 50_000_000, // 50 ADA
      merchantId: '6650dbcb5e0cf7001bb05abc',
      invoiceId: 'INV-20260525-OK',
    });

    expect(profile.riskScore).toBeLessThan(40);
    expect(profile.isHighVelocity).toBe(false);
    expect(profile.suggestedAction).toBe('approve');
    expect(profile.riskFlags).toHaveLength(0);
  });

  it('should flag high-velocity wallets with elevated risk scores and hold recommendations', async () => {
    // Fill sliding window to trigger limit (> 10 items)
    for (let i = 0; i < 11; i++) {
      await upstashRedis.zadd('velocity:count:addr_test1qrrvelocity', { score: Date.now(), member: `test-mem-${i}` });
      await upstashRedis.zadd('velocity:volume:addr_test1qrrvelocity', { score: Date.now(), member: `test-mem-${i}:5000000` });
    }

    const profile = await RiskScorer.analyzeTransaction({
      walletAddress: 'addr_test1qrrvelocity',
      amountLovelace: 5_000_000,
      merchantId: '6650dbcb5e0cf7001bb05abc',
      invoiceId: 'INV-20260525-FAST',
    });

    expect(profile.isHighVelocity).toBe(true);
    expect(profile.riskScore).toBeGreaterThanOrEqual(40);
    expect(profile.suggestedAction).toBe('hold');
    expect(profile.riskFlags).toContain('wallet:high-transaction-count');
  });

  it('should detect suspicious wallet address formats and elevate risk levels', async () => {
    const profile = await RiskScorer.analyzeTransaction({
      walletAddress: 'addr_test1qqqqsuspiciouswalletaddresszzzz',
      amountLovelace: 10_000_000,
      merchantId: '6650dbcb5e0cf7001bb05abc',
      invoiceId: 'INV-20260525-FLAGGED',
    });

    expect(profile.isSuspiciousAddress).toBe(true);
    expect(profile.riskScore).toBeGreaterThanOrEqual(35);
    expect(profile.riskFlags).toContain('wallet:suspicious-address-pattern');
  });
});
