import { Request, Response, NextFunction, Router } from 'express';
import { getSocketServer } from '../config/socketServer';
import { circuitRegistry } from '../config/circuitBreaker';
import {
  txConfirmationQueue,
  receiptQueue,
  notificationQueue,
  expiryQueue,
  dailyStatsQueue,
  disputeResolutionQueue,
  webhookQueue,
  digitalDeliveryQueue,
} from '../queues/queue.definitions';

// In-memory metrics counters
const requestCounts: Record<string, number> = {};
const responseTimes: number[] = [];
const statusCounts: Record<number, number> = {};
let totalRequests = 0;

export function metricsCollector(req: Request, res: Response, next: NextFunction): void {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    const routeKey = `${req.method} ${req.route?.path || req.path}`;
    requestCounts[routeKey] = (requestCounts[routeKey] || 0) + 1;
    statusCounts[res.statusCode] = (statusCounts[res.statusCode] || 0) + 1;
    responseTimes.push(duration);
    totalRequests++;

    // Keep response times array bounded (last 10000 entries)
    if (responseTimes.length > 10000) {
      responseTimes.splice(0, responseTimes.length - 10000);
    }
  });
  next();
}

function percentile(arr: number[], p: number): number {
  if (arr.length === 0) return 0;
  const sorted = [...arr].sort((a, b) => a - b);
  const idx = Math.ceil((p / 100) * sorted.length) - 1;
  return sorted[Math.max(0, idx)];
}

export function createMetricsRouter(): Router {
  const router = Router();

  router.get('/', async (_req: Request, res: Response) => {
    const lines: string[] = [
      '# HELP zeropay_requests_total Total number of HTTP requests',
      '# TYPE zeropay_requests_total counter',
      `zeropay_requests_total ${totalRequests}`,
      '',
      '# HELP zeropay_response_duration_ms Response time percentiles',
      '# TYPE zeropay_response_duration_ms gauge',
      `zeropay_response_duration_ms{quantile="0.5"} ${percentile(responseTimes, 50)}`,
      `zeropay_response_duration_ms{quantile="0.95"} ${percentile(responseTimes, 95)}`,
      `zeropay_response_duration_ms{quantile="0.99"} ${percentile(responseTimes, 99)}`,
      '',
      '# HELP zeropay_http_status_total HTTP response status codes',
      '# TYPE zeropay_http_status_total counter',
    ];

    for (const [status, count] of Object.entries(statusCounts)) {
      lines.push(`zeropay_http_status_total{status="${status}"} ${count}`);
    }

    lines.push('');
    lines.push('# HELP zeropay_route_requests_total Requests per route');
    lines.push('# TYPE zeropay_route_requests_total counter');

    for (const [route, count] of Object.entries(requestCounts)) {
      const safeRoute = route.replace(/"/g, '');
      lines.push(`zeropay_route_requests_total{route="${safeRoute}"} ${count}`);
    }

    // ─── Socket.IO active connections metrics ──────────────────────────────
    lines.push('');
    lines.push('# HELP zeropay_socket_connections_total Total active Socket.IO connections');
    lines.push('# TYPE zeropay_socket_connections_total gauge');
    let activeSockets = 0;
    try {
      const io = getSocketServer();
      activeSockets = io.sockets.sockets.size;
    } catch {
      // Socket server not active or initialized
    }
    lines.push(`zeropay_socket_connections_total ${activeSockets}`);

    // ─── Circuit Breaker state metrics ─────────────────────────────────────
    lines.push('');
    lines.push('# HELP zeropay_circuit_breaker_state Current state of circuit breakers (0=CLOSED, 1=OPEN, 2=HALF_OPEN)');
    lines.push('# TYPE zeropay_circuit_breaker_state gauge');
    lines.push('# HELP zeropay_circuit_breaker_failures Total caught failures per circuit');
    lines.push('# TYPE zeropay_circuit_breaker_failures counter');

    const breakers = circuitRegistry.getBreakers();
    for (const b of breakers) {
      const stats = b.getStats();
      const stateVal = stats.state === 'CLOSED' ? 0 : stats.state === 'OPEN' ? 1 : 2;
      lines.push(`zeropay_circuit_breaker_state{breaker="${b.name}"} ${stateVal}`);
      lines.push(`zeropay_circuit_breaker_failures{breaker="${b.name}"} ${stats.failureCount}`);
    }

    // ─── BullMQ queue depths metrics ─────────────────────────────────────────
    lines.push('');
    lines.push('# HELP zeropay_queue_jobs_total Number of BullMQ jobs in various states');
    lines.push('# TYPE zeropay_queue_jobs_total gauge');

    const queues = [
      { name: 'tx-confirmation', queue: txConfirmationQueue },
      { name: 'receipt-generation', queue: receiptQueue },
      { name: 'notification-dispatch', queue: notificationQueue },
      { name: 'invoice-expiry', queue: expiryQueue },
      { name: 'daily-stats', queue: dailyStatsQueue },
      { name: 'dispute-resolution', queue: disputeResolutionQueue },
      { name: 'webhook-delivery', queue: webhookQueue },
      { name: 'digital-delivery', queue: digitalDeliveryQueue },
    ];

    try {
      const queueMetrics = await Promise.all(
        queues.map(async ({ name, queue }) => {
          const counts = await queue.getJobCounts('waiting', 'active', 'failed', 'delayed');
          return { name, counts };
        })
      );

      for (const q of queueMetrics) {
        lines.push(`zeropay_queue_jobs_total{queue="${q.name}",state="waiting"} ${q.counts.waiting}`);
        lines.push(`zeropay_queue_jobs_total{queue="${q.name}",state="active"} ${q.counts.active}`);
        lines.push(`zeropay_queue_jobs_total{queue="${q.name}",state="failed"} ${q.counts.failed}`);
        lines.push(`zeropay_queue_jobs_total{queue="${q.name}",state="delayed"} ${q.counts.delayed}`);
      }
    } catch (err: any) {
      lines.push(`# ERROR: Failed to collect queue depths metrics: ${err.message}`);
    }

    res.setHeader('Content-Type', 'text/plain; charset=utf-8');
    res.send(lines.join('\n') + '\n');
  });

  return router;
}
