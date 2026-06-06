import { Router, Request, Response } from 'express';
import { requireAuth, requireRole } from '../middleware/auth';
import { computeSLOReport } from '../services/slaAuditor';
import { logger } from '../config/logger';

const router = Router();

/**
 * GET /api/v1/ops/slo
 * Admin-only SLO/SLA compliance report for the past 24 hours (configurable).
 * Query param: ?windowHours=48 (default: 24)
 */
router.get(
  '/slo',
  requireAuth,
  requireRole('admin'),
  async (req: Request, res: Response): Promise<void> => {
    try {
      const windowHours = Math.min(
        168, // Max 7-day window
        Math.max(1, parseInt((req.query.windowHours as string) ?? '24', 10) || 24)
      );

      const report = await computeSLOReport(windowHours);

      res.json({
        success: true,
        data: report,
      });
    } catch (err: any) {
      logger.error('[ops] SLO report generation failed', { error: err.message });
      res.status(500).json({ success: false, error: 'SLO report generation failed' });
    }
  }
);

/**
 * GET /api/v1/ops/slo/prometheus
 * Returns SLO metrics in Prometheus exposition format for scraping.
 */
router.get(
  '/slo/prometheus',
  requireAuth,
  requireRole('admin'),
  async (req: Request, res: Response): Promise<void> => {
    try {
      const report = await computeSLOReport(24);

      const lines = [
        `# HELP zeropay_slo_escrow_success_rate_pct Percentage of escrow locks that reached settlement`,
        `# TYPE zeropay_slo_escrow_success_rate_pct gauge`,
        `zeropay_slo_escrow_success_rate_pct ${report.escrowSuccessRatePct}`,
        `# HELP zeropay_slo_avg_lock_confirm_latency_ms Average escrow lock confirmation latency in milliseconds`,
        `# TYPE zeropay_slo_avg_lock_confirm_latency_ms gauge`,
        `zeropay_slo_avg_lock_confirm_latency_ms ${report.avgLockConfirmLatencyMs}`,
        `# HELP zeropay_slo_avg_dispute_resolution_ms Average dispute resolution time in milliseconds`,
        `# TYPE zeropay_slo_avg_dispute_resolution_ms gauge`,
        `zeropay_slo_avg_dispute_resolution_ms ${report.avgDisputeResolutionMs}`,
        `# HELP zeropay_slo_risk_block_rate_pct Percentage of checkout lock attempts blocked by fraud risk scorer`,
        `# TYPE zeropay_slo_risk_block_rate_pct gauge`,
        `zeropay_slo_risk_block_rate_pct ${report.riskBlockRatePct}`,
        `# HELP zeropay_slo_violations_total Total number of active SLA violations in the reporting window`,
        `# TYPE zeropay_slo_violations_total gauge`,
        `zeropay_slo_violations_total ${report.slaViolations.length}`,
      ].join('\n');

      res.setHeader('Content-Type', 'text/plain; version=0.0.4');
      res.send(lines + '\n');
    } catch (err: any) {
      logger.error('[ops] SLO prometheus export failed', { error: err.message });
      res.status(500).send('# SLO metrics unavailable\n');
    }
  }
);

export default router;
