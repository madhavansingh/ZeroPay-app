import { Router, Request, Response } from 'express';
import { requireAuth } from '../middleware/auth';
import { TelemetryLog } from '../models/TelemetryLog';
import { AIAuditLog } from '../models/AIAuditLog';

const router = Router();

// POST /api/v1/telemetry/events
router.post('/events', requireAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const { parameters, timestamp } = req.body;
    const name = req.body.name || req.body.event_name;

    if (!name) {
      res.status(400).json({ success: false, error: 'Name (or event_name) is required' });
      return;
    }

    const log = await TelemetryLog.create({
      type: 'event',
      name,
      parameters,
      timestamp: timestamp ? new Date(timestamp) : new Date(),
    });

    // If telemetry name matches AI actions, log them into AIAuditLog
    const nameLower = name.toLowerCase();
    if (nameLower.includes('ai') || nameLower.includes('agent') || nameLower.includes('negotiat') || nameLower.includes('dispute')) {
      await AIAuditLog.create({
        action: name.slice(0, 50),
        actorId: req.user._id.toString(),
        promptTemplate: 'telemetry-event',
        inputData: parameters || {},
        latencyMs: parameters?.latencyMs || 0,
        status: parameters?.status === 'failure' ? 'failure' : 'success',
        invoiceId: parameters?.invoiceId,
        requestId: res.locals['requestId'] || parameters?.requestId,
      }).catch((err) => console.error('Failed to log AI audit log from telemetry event:', err.message));
    }

    res.status(200).json({ success: true, data: log });
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Failed to record event';
    res.status(500).json({ success: false, error: message });
  }
});

// POST /api/v1/telemetry/metrics
router.post('/metrics', requireAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const { value, parameters, timestamp } = req.body;
    const name = req.body.name || req.body.metric;

    if (!name) {
      res.status(400).json({ success: false, error: 'Name (or metric) is required' });
      return;
    }

    const log = await TelemetryLog.create({
      type: 'metric',
      name,
      value: typeof value === 'number' ? value : undefined,
      parameters,
      timestamp: timestamp ? new Date(timestamp) : new Date(),
    });

    // If telemetry name matches AI actions, log them into AIAuditLog
    const nameLower = name.toLowerCase();
    if (nameLower.includes('ai') || nameLower.includes('agent') || nameLower.includes('negotiat') || nameLower.includes('dispute')) {
      await AIAuditLog.create({
        action: name.slice(0, 50),
        actorId: req.user._id.toString(),
        promptTemplate: 'telemetry-metric',
        inputData: { value, ...(parameters || {}) },
        latencyMs: value || parameters?.latencyMs || 0,
        status: parameters?.status === 'failure' ? 'failure' : 'success',
        invoiceId: parameters?.invoiceId,
        requestId: res.locals['requestId'] || parameters?.requestId,
      }).catch((err) => console.error('Failed to log AI audit log from telemetry metric:', err.message));
    }

    res.status(200).json({ success: true, data: log });
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Failed to record metric';
    res.status(500).json({ success: false, error: message });
  }
});

export default router;
