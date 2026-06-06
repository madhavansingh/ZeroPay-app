import { Request, Response, NextFunction } from 'express';
import { RiskScorer } from '../services/riskScorer';
import { Invoice } from '../models/Invoice';
import { ProtocolAuditLog } from '../models/ProtocolAuditLog';
import { logger } from '../config/logger';

export interface RiskRequest extends Request {
  riskProfile?: any;
}

export async function riskMiddleware(
  req: RiskRequest,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const { invoiceId } = req.params;
    const { customerAddress } = req.body;

    if (!invoiceId) {
      res.status(400).json({ success: false, error: 'invoiceId parameter is required' });
      return;
    }

    if (!customerAddress) {
      res.status(400).json({ success: false, error: 'customerAddress body field is required' });
      return;
    }

    // 1. Fetch corresponding invoice to determine pricing/merchant details
    const invoice = await Invoice.findOne({ invoiceId });
    if (!invoice) {
      res.status(404).json({ success: false, error: 'Invoice not found for risk assessment' });
      return;
    }

    // 2. Perform Transaction Analysis
    const profile = await RiskScorer.analyzeTransaction({
      walletAddress: customerAddress,
      amountLovelace: invoice.amountLovelace,
      merchantId: invoice.merchantId.toString(),
      invoiceId: invoice.invoiceId,
    });

    // Attach risk profile for down-stream processing if required
    req.riskProfile = profile;

    // 3. Evaluate Risk Policy Action
    if (profile.suggestedAction === 'block' || profile.riskScore >= 80) {
      const requestId = res.locals.requestId || 'system';
      const actorId = req.user ? req.user.id : 'anonymous-customer';

      logger.warn('[RiskMiddleware] High risk transaction blocked automatically', {
        invoiceId,
        customerAddress,
        riskScore: profile.riskScore,
        flags: profile.riskFlags.join(','),
      });

      // Write immutable anomaly entry into Protocol Audit Trail
      await ProtocolAuditLog.create({
        eventType: 'RiskAssessmentAnomaly',
        status: 'failure',
        actorId,
        requestId,
        invoiceId,
        metadata: {
          customerAddress,
          riskScore: profile.riskScore,
          riskFlags: profile.riskFlags,
          rationale: profile.rationale,
          suggestedAction: profile.suggestedAction,
        },
        details: `Blocked lock transaction due to high fraud risk score (${profile.riskScore}/100). Rationale: ${profile.rationale}`,
      });

      res.status(403).json({
        success: false,
        error: 'Transaction rejected due to risk and fraud policy compliance',
        riskProfile: {
          riskScore: profile.riskScore,
          riskFlags: profile.riskFlags,
          rationale: profile.rationale,
        },
      });
      return;
    }

    // If suggested action is hold, let transaction proceed but log details in request
    if (profile.suggestedAction === 'hold') {
      logger.info('[RiskMiddleware] Transaction flagged with medium risk hold warning', {
        invoiceId,
        riskScore: profile.riskScore,
        flags: profile.riskFlags.join(','),
      });
    }

    next();
  } catch (err: any) {
    logger.error('[RiskMiddleware] Fatal error running transaction risk evaluation', {
      error: err.message,
    });
    // In case of fatal risk scorer crash, fall back to fail-safe (allow checkout with warnings)
    next();
  }
}
