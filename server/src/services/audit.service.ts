import { ProtocolAuditLog } from '../models/ProtocolAuditLog';
import { logger } from '../config/logger';

export interface AuditParams {
  eventType: string;
  status: 'success' | 'failure';
  actorId: string;
  requestId?: string;
  invoiceId?: string;
  metadata?: Record<string, any>;
  details: string;
}

/**
 * Centrally log platform and protocol activity to the immutable ProtocolAuditLog collection.
 */
export async function logProtocolActivity(params: AuditParams): Promise<void> {
  try {
    await ProtocolAuditLog.create({
      timestamp: new Date(),
      eventType: params.eventType,
      status: params.status,
      actorId: params.actorId,
      requestId: params.requestId,
      invoiceId: params.invoiceId,
      metadata: params.metadata || {},
      details: params.details,
    });
    logger.debug(`[Audit] Logged protocol activity: ${params.eventType}`, { invoiceId: params.invoiceId });
  } catch (err: any) {
    logger.error('[Audit] Failed to create protocol activity log:', { detail: err.message });
  }
}
