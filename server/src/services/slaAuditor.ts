import { ProtocolAuditLog } from '../models/ProtocolAuditLog';
import { logger } from '../config/logger';

export interface SLOReport {
  generatedAt: string;
  windowHours: number;
  escrowSuccessRatePct: number;         // % of locks that reached 'settled' or 'released'
  avgLockConfirmLatencyMs: number;      // avg ms from EscrowLocked to EscrowConfirmed
  avgDisputeResolutionMs: number;       // avg ms from DisputeRaised to DisputeResolved
  riskBlockRatePct: number;             // % of lock attempts blocked by risk scorer
  totalAuditEvents: number;
  slaViolations: SLAViolation[];
}

export interface SLAViolation {
  type: string;
  threshold: string;
  actual: string;
  severity: 'warning' | 'critical';
}

// SLA target thresholds
const SLA_TARGETS = {
  escrowSuccessRate: 95,          // % — below this is a warning
  lockConfirmLatencyMs: 120_000,  // 120 seconds
  disputeResolutionMs: 86_400_000, // 24 hours
  riskBlockRatePct: 5,            // >5% of attempts blocked is suspicious
} as const;

export async function computeSLOReport(windowHours = 24): Promise<SLOReport> {
  const since = new Date(Date.now() - windowHours * 3_600_000);
  const violations: SLAViolation[] = [];

  logger.info('[SLAudit] Computing SLO report', { windowHours });

  // Fetch all audit events within the window
  // NOTE: ProtocolAuditLog uses `timestamp` (not createdAt) as its date field
  const events = await ProtocolAuditLog.find(
    { timestamp: { $gte: since } },
    { eventType: 1, status: 1, timestamp: 1, invoiceId: 1, metadata: 1 }
  ).lean();

  const totalAuditEvents = events.length;

  // ── 1. Escrow Success Rate ──────────────────────────────────────────────────
  const lockEvents = events.filter((e) => e.eventType === 'EscrowLocked');
  const releaseEvents = events.filter(
    (e) => e.eventType === 'EscrowReleased' || e.eventType === 'EscrowResolved'
  );
  const releasedInvoices = new Set(releaseEvents.map((e) => e.invoiceId));
  const successCount = lockEvents.filter((e) =>
    releasedInvoices.has(e.invoiceId)
  ).length;
  const escrowSuccessRatePct =
    lockEvents.length > 0
      ? Math.round((successCount / lockEvents.length) * 10000) / 100
      : 100;

  if (lockEvents.length >= 5 && escrowSuccessRatePct < SLA_TARGETS.escrowSuccessRate) {
    violations.push({
      type: 'EscrowSuccessRate',
      threshold: `>= ${SLA_TARGETS.escrowSuccessRate}%`,
      actual: `${escrowSuccessRatePct}%`,
      severity: escrowSuccessRatePct < 80 ? 'critical' : 'warning',
    });
  }

  // ── 2. Average Lock Confirmation Latency ───────────────────────────────────
  const confirmEvents = events.filter((e) => e.eventType === 'EscrowConfirmed');
  const lockTimesById: Record<string, Date> = {};
  for (const e of lockEvents) {
    if (e.invoiceId) lockTimesById[e.invoiceId] = e.timestamp;
  }
  const latencies: number[] = [];
  for (const conf of confirmEvents) {
    if (conf.invoiceId && lockTimesById[conf.invoiceId]) {
      latencies.push(
        new Date(conf.timestamp).getTime() - new Date(lockTimesById[conf.invoiceId]).getTime()
      );
    }
  }
  const avgLockConfirmLatencyMs =
    latencies.length > 0
      ? Math.round(latencies.reduce((a, b) => a + b, 0) / latencies.length)
      : 0;

  if (avgLockConfirmLatencyMs > SLA_TARGETS.lockConfirmLatencyMs && latencies.length >= 3) {
    violations.push({
      type: 'LockConfirmLatency',
      threshold: `<= ${SLA_TARGETS.lockConfirmLatencyMs / 1000}s`,
      actual: `${Math.round(avgLockConfirmLatencyMs / 1000)}s avg`,
      severity: avgLockConfirmLatencyMs > SLA_TARGETS.lockConfirmLatencyMs * 2 ? 'critical' : 'warning',
    });
  }

  // ── 3. Dispute Resolution MTTR ─────────────────────────────────────────────
  const disputeEvents = events.filter((e) => e.eventType === 'DisputeRaised');
  const resolveEvents = events.filter((e) => e.eventType === 'DisputeResolved');
  const disputeTimesById: Record<string, Date> = {};
  for (const e of disputeEvents) {
    if (e.invoiceId) disputeTimesById[e.invoiceId] = e.timestamp;
  }
  const resolutionLatencies: number[] = [];
  for (const res of resolveEvents) {
    if (res.invoiceId && disputeTimesById[res.invoiceId]) {
      resolutionLatencies.push(
        new Date(res.timestamp).getTime() -
          new Date(disputeTimesById[res.invoiceId]).getTime()
      );
    }
  }
  const avgDisputeResolutionMs =
    resolutionLatencies.length > 0
      ? Math.round(
          resolutionLatencies.reduce((a, b) => a + b, 0) / resolutionLatencies.length
        )
      : 0;

  if (
    avgDisputeResolutionMs > SLA_TARGETS.disputeResolutionMs &&
    resolutionLatencies.length >= 1
  ) {
    violations.push({
      type: 'DisputeResolutionMTTR',
      threshold: `<= 24 hours`,
      actual: `${Math.round(avgDisputeResolutionMs / 3_600_000)}h avg`,
      severity: avgDisputeResolutionMs > SLA_TARGETS.disputeResolutionMs * 2 ? 'critical' : 'warning',
    });
  }

  // ── 4. Risk Block Rate ─────────────────────────────────────────────────────
  const riskBlocks = events.filter((e) => e.eventType === 'RiskAssessmentAnomaly').length;
  const lockAttempts = lockEvents.length + riskBlocks;
  const riskBlockRatePct =
    lockAttempts > 0
      ? Math.round((riskBlocks / lockAttempts) * 10000) / 100
      : 0;

  if (riskBlockRatePct > SLA_TARGETS.riskBlockRatePct && lockAttempts >= 10) {
    violations.push({
      type: 'RiskBlockRate',
      threshold: `<= ${SLA_TARGETS.riskBlockRatePct}%`,
      actual: `${riskBlockRatePct}%`,
      severity: riskBlockRatePct > 20 ? 'critical' : 'warning',
    });
  }

  const report: SLOReport = {
    generatedAt: new Date().toISOString(),
    windowHours,
    escrowSuccessRatePct,
    avgLockConfirmLatencyMs,
    avgDisputeResolutionMs,
    riskBlockRatePct,
    totalAuditEvents,
    slaViolations: violations,
  };

  logger.info('[SLAudit] SLO report computed', {
    windowHours,
    violations: violations.length,
    escrowSuccessRatePct,
  });

  return report;
}
