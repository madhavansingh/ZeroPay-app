import { describe, it, expect, vi, beforeEach } from 'vitest';

// 1. Mock env variables to prevent schema validation crashes
vi.mock('../../src/config/env', () => ({
  env: {
    NODE_ENV: 'test',
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

// Mock Mongoose Model
const mockFindLean = vi.fn().mockResolvedValue([]);
vi.mock('../../src/models/ProtocolAuditLog', () => ({
  ProtocolAuditLog: {
    find: vi.fn(() => ({
      lean: mockFindLean,
    })),
  },
}));

import { computeSLOReport } from '../../src/services/slaAuditor';
import { ProtocolAuditLog } from '../../src/models/ProtocolAuditLog';

describe('SLA/SLO Auditor Service', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockFindLean.mockResolvedValue([]);
  });

  it('should return 100% success rate and no violations when no events exist', async () => {
    const report = await computeSLOReport(24);

    expect(report.totalAuditEvents).toBe(0);
    expect(report.escrowSuccessRatePct).toBe(100);
    expect(report.avgLockConfirmLatencyMs).toBe(0);
    expect(report.avgDisputeResolutionMs).toBe(0);
    expect(report.riskBlockRatePct).toBe(0);
    expect(report.slaViolations).toEqual([]);
    expect(ProtocolAuditLog.find).toHaveBeenCalled();
  });

  it('should compute correct escrow success rate and add critical violation if below 80%', async () => {
    const mockEvents = [
      { eventType: 'EscrowLocked', invoiceId: 'inv-1', timestamp: new Date() },
      { eventType: 'EscrowLocked', invoiceId: 'inv-2', timestamp: new Date() },
      { eventType: 'EscrowLocked', invoiceId: 'inv-3', timestamp: new Date() },
      { eventType: 'EscrowLocked', invoiceId: 'inv-4', timestamp: new Date() },
      { eventType: 'EscrowLocked', invoiceId: 'inv-5', timestamp: new Date() },
      // Only 3/5 succeeded (released or resolved) -> 60% (which is < 80% so critical)
      { eventType: 'EscrowReleased', invoiceId: 'inv-1', timestamp: new Date() },
      { eventType: 'EscrowReleased', invoiceId: 'inv-2', timestamp: new Date() },
      { eventType: 'EscrowResolved', invoiceId: 'inv-3', timestamp: new Date() },
    ];
    mockFindLean.mockResolvedValue(mockEvents);

    const report = await computeSLOReport(24);

    expect(report.totalAuditEvents).toBe(8);
    expect(report.escrowSuccessRatePct).toBe(60);
    expect(report.slaViolations.length).toBe(1);
    expect(report.slaViolations[0]).toEqual({
      type: 'EscrowSuccessRate',
      threshold: '>= 95%',
      actual: '60%',
      severity: 'critical',
    });
  });

  it('should compute correct escrow success rate and add warning violation if between 80% and 95%', async () => {
    // 9/10 locks succeeded -> 90% (which is >= 80% and < 95% so warning)
    const mockEvents = [];
    for (let i = 1; i <= 10; i++) {
      mockEvents.push({ eventType: 'EscrowLocked', invoiceId: `inv-${i}`, timestamp: new Date() });
    }
    // Succeeded events (9 of them)
    for (let i = 1; i <= 9; i++) {
      mockEvents.push({ eventType: 'EscrowReleased', invoiceId: `inv-${i}`, timestamp: new Date() });
    }
    mockFindLean.mockResolvedValue(mockEvents);

    const report = await computeSLOReport(24);

    expect(report.escrowSuccessRatePct).toBe(90);
    expect(report.slaViolations.length).toBe(1);
    expect(report.slaViolations[0]).toEqual({
      type: 'EscrowSuccessRate',
      threshold: '>= 95%',
      actual: '90%',
      severity: 'warning',
    });
  });

  it('should compute average lock confirmation latency and trigger warning/critical violations', async () => {
    const now = Date.now();
    const mockEvents = [
      // Need at least 3 latencies to trigger violation
      { eventType: 'EscrowLocked', invoiceId: 'inv-1', timestamp: new Date(now - 150000) },
      { eventType: 'EscrowConfirmed', invoiceId: 'inv-1', timestamp: new Date(now) }, // 150s lag

      { eventType: 'EscrowLocked', invoiceId: 'inv-2', timestamp: new Date(now - 200000) },
      { eventType: 'EscrowConfirmed', invoiceId: 'inv-2', timestamp: new Date(now) }, // 200s lag

      { eventType: 'EscrowLocked', invoiceId: 'inv-3', timestamp: new Date(now - 100000) },
      { eventType: 'EscrowConfirmed', invoiceId: 'inv-3', timestamp: new Date(now) }, // 100s lag
    ];
    mockFindLean.mockResolvedValue(mockEvents);

    const report = await computeSLOReport(24);

    // Average lag: (150s + 200s + 100s) / 3 = 150s = 150000ms
    expect(report.avgLockConfirmLatencyMs).toBe(150000);
    expect(report.slaViolations.length).toBe(1);
    expect(report.slaViolations[0]).toEqual({
      type: 'LockConfirmLatency',
      threshold: '<= 120s',
      actual: '150s avg',
      severity: 'warning', // 150s <= 240s (SLA_TARGETS.lockConfirmLatencyMs * 2)
    });
  });

  it('should trigger critical lock confirmation latency if average is over 2x threshold', async () => {
    const now = Date.now();
    const mockEvents = [
      { eventType: 'EscrowLocked', invoiceId: 'inv-1', timestamp: new Date(now - 300000) },
      { eventType: 'EscrowConfirmed', invoiceId: 'inv-1', timestamp: new Date(now) }, // 300s lag

      { eventType: 'EscrowLocked', invoiceId: 'inv-2', timestamp: new Date(now - 250000) },
      { eventType: 'EscrowConfirmed', invoiceId: 'inv-2', timestamp: new Date(now) }, // 250s lag

      { eventType: 'EscrowLocked', invoiceId: 'inv-3', timestamp: new Date(now - 260000) },
      { eventType: 'EscrowConfirmed', invoiceId: 'inv-3', timestamp: new Date(now) }, // 260s lag
    ];
    mockFindLean.mockResolvedValue(mockEvents);

    const report = await computeSLOReport(24);

    // Average: 270s = 270000ms (> 240000ms threshold * 2)
    expect(report.avgLockConfirmLatencyMs).toBe(270000);
    expect(report.slaViolations.length).toBe(1);
    expect(report.slaViolations[0].severity).toBe('critical');
  });

  it('should compute average dispute resolution MTTR and trigger violations', async () => {
    const now = Date.now();
    const mockEvents = [
      // Need at least 1 latency to trigger
      { eventType: 'DisputeRaised', invoiceId: 'inv-1', timestamp: new Date(now - 30 * 3600 * 1000) },
      { eventType: 'DisputeResolved', invoiceId: 'inv-1', timestamp: new Date(now) }, // 30h dispute
    ];
    mockFindLean.mockResolvedValue(mockEvents);

    const report = await computeSLOReport(24);

    expect(report.avgDisputeResolutionMs).toBe(30 * 3600 * 1000);
    expect(report.slaViolations.length).toBe(1);
    expect(report.slaViolations[0]).toEqual({
      type: 'DisputeResolutionMTTR',
      threshold: '<= 24 hours',
      actual: '30h avg',
      severity: 'warning', // 30h <= 48h (SLA_TARGETS.disputeResolutionMs * 2)
    });
  });

  it('should compute risk block rate and trigger violations if suspicious (with locks succeeded to avoid other violations)', async () => {
    const mockEvents = [
      // 8 lock events, and ALL of them succeeded (released) to avoid EscrowSuccessRate violations
      { eventType: 'EscrowLocked', invoiceId: 'inv-1', timestamp: new Date() },
      { eventType: 'EscrowReleased', invoiceId: 'inv-1', timestamp: new Date() },

      { eventType: 'EscrowLocked', invoiceId: 'inv-2', timestamp: new Date() },
      { eventType: 'EscrowReleased', invoiceId: 'inv-2', timestamp: new Date() },

      { eventType: 'EscrowLocked', invoiceId: 'inv-3', timestamp: new Date() },
      { eventType: 'EscrowReleased', invoiceId: 'inv-3', timestamp: new Date() },

      { eventType: 'EscrowLocked', invoiceId: 'inv-4', timestamp: new Date() },
      { eventType: 'EscrowReleased', invoiceId: 'inv-4', timestamp: new Date() },

      { eventType: 'EscrowLocked', invoiceId: 'inv-5', timestamp: new Date() },
      { eventType: 'EscrowReleased', invoiceId: 'inv-5', timestamp: new Date() },

      { eventType: 'EscrowLocked', invoiceId: 'inv-6', timestamp: new Date() },
      { eventType: 'EscrowReleased', invoiceId: 'inv-6', timestamp: new Date() },

      { eventType: 'EscrowLocked', invoiceId: 'inv-7', timestamp: new Date() },
      { eventType: 'EscrowReleased', invoiceId: 'inv-7', timestamp: new Date() },

      { eventType: 'EscrowLocked', invoiceId: 'inv-8', timestamp: new Date() },
      { eventType: 'EscrowReleased', invoiceId: 'inv-8', timestamp: new Date() },

      // 2 blocks + 8 locks = 10 attempts (20% rate)
      { eventType: 'RiskAssessmentAnomaly', invoiceId: 'inv-9', timestamp: new Date() },
      { eventType: 'RiskAssessmentAnomaly', invoiceId: 'inv-10', timestamp: new Date() },
    ];
    mockFindLean.mockResolvedValue(mockEvents);

    const report = await computeSLOReport(24);

    expect(report.riskBlockRatePct).toBe(20);
    expect(report.slaViolations.length).toBe(1);
    expect(report.slaViolations[0]).toEqual({
      type: 'RiskBlockRate',
      threshold: '<= 5%',
      actual: '20%',
      severity: 'warning',
    });
  });

  it('should trigger critical risk block rate if above 20% (with locks succeeded to avoid other violations)', async () => {
    const mockEvents = [
      // 7 lock events, all succeeded
      { eventType: 'EscrowLocked', invoiceId: 'inv-1', timestamp: new Date() },
      { eventType: 'EscrowReleased', invoiceId: 'inv-1', timestamp: new Date() },

      { eventType: 'EscrowLocked', invoiceId: 'inv-2', timestamp: new Date() },
      { eventType: 'EscrowReleased', invoiceId: 'inv-2', timestamp: new Date() },

      { eventType: 'EscrowLocked', invoiceId: 'inv-3', timestamp: new Date() },
      { eventType: 'EscrowReleased', invoiceId: 'inv-3', timestamp: new Date() },

      { eventType: 'EscrowLocked', invoiceId: 'inv-4', timestamp: new Date() },
      { eventType: 'EscrowReleased', invoiceId: 'inv-4', timestamp: new Date() },

      { eventType: 'EscrowLocked', invoiceId: 'inv-5', timestamp: new Date() },
      { eventType: 'EscrowReleased', invoiceId: 'inv-5', timestamp: new Date() },

      { eventType: 'EscrowLocked', invoiceId: 'inv-6', timestamp: new Date() },
      { eventType: 'EscrowReleased', invoiceId: 'inv-6', timestamp: new Date() },

      { eventType: 'EscrowLocked', invoiceId: 'inv-7', timestamp: new Date() },
      { eventType: 'EscrowReleased', invoiceId: 'inv-7', timestamp: new Date() },

      // 3 blocks + 7 locks = 10 attempts (30% rate)
      { eventType: 'RiskAssessmentAnomaly', invoiceId: 'inv-8', timestamp: new Date() },
      { eventType: 'RiskAssessmentAnomaly', invoiceId: 'inv-9', timestamp: new Date() },
      { eventType: 'RiskAssessmentAnomaly', invoiceId: 'inv-10', timestamp: new Date() },
    ];
    mockFindLean.mockResolvedValue(mockEvents);

    const report = await computeSLOReport(24);

    expect(report.riskBlockRatePct).toBe(30);
    expect(report.slaViolations.length).toBe(1);
    expect(report.slaViolations[0].severity).toBe('critical');
  });
});
