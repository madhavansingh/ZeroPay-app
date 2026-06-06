import 'dotenv/config';
import { initSentry, Sentry } from './config/sentry';
// Initialize Sentry before anything else
initSentry();

import mongoose from 'mongoose';
import { env } from './config/env';
import { logger } from './config/logger';
import { connectDatabase } from './config/db';
import { initFirebase } from './config/firebase-admin';
import { bullMqRedis } from './config/redis';
import { initSubscribers } from './events/subscribers';

import { startConfirmationWorker } from './workers/confirmation.worker';
import { startReceiptWorker } from './workers/receipt.worker';
import { startNotificationWorker } from './workers/notification.worker';
import { startExpiryWorker } from './workers/expiry.worker';
import { startDailyStatsWorker } from './workers/dailyStats.worker';
import { startReconciliationWorker } from './workers/reconciliation.worker';
import { startDigitalDeliveryWorker } from './workers/digital-delivery.worker';
import { startWebhookDeliveryWorker } from './workers/webhook-delivery.worker';
import { startDisputeResolutionWorker } from './workers/dispute-resolution.worker';
import { dailyStatsQueue } from './queues/queue.definitions';
import type { Worker } from 'bullmq';

// ── Global error handlers (process-level safety net) ─────────────────────────
process.on('uncaughtException', (err: Error) => {
  logger.error('Uncaught exception in Worker — shutting down', { detail: err.message });
  Sentry.captureException(err);
  process.exit(1);
});

process.on('unhandledRejection', (reason: unknown) => {
  const msg = reason instanceof Error ? reason.message : String(reason);
  logger.error('Unhandled promise rejection in Worker', { detail: msg });
  Sentry.captureException(reason instanceof Error ? reason : new Error(msg));
});

async function bootstrapWorker(): Promise<void> {
  initFirebase();
  await connectDatabase();
  initSubscribers();

  // ── Mongoose connection lifecycle logging ──────────────────────────────────
  mongoose.connection.on('disconnected', () => logger.warn('MongoDB disconnected in Worker'));
  mongoose.connection.on('reconnected', () => logger.info('MongoDB reconnected in Worker'));
  mongoose.connection.on('error', (err) => logger.error('MongoDB error in Worker', { detail: err.message }));

  logger.info('Worker process bootstrapping...');

  // ── Start BullMQ workers ──────────────────────────────────────────────────
  const workers: Worker[] = [];
  workers.push(startConfirmationWorker());
  workers.push(startReceiptWorker());
  workers.push(startNotificationWorker());
  workers.push(startDailyStatsWorker());
  workers.push(await startExpiryWorker());
  workers.push(await startReconciliationWorker());
  workers.push(startDigitalDeliveryWorker());
  workers.push(startWebhookDeliveryWorker());
  workers.push(startDisputeResolutionWorker());

  // Schedule nightly stats sync at 00:05 IST (18:35 UTC)
  try {
    await dailyStatsQueue.add(
      'nightly-sync',
      {},
      {
        repeat: { pattern: '35 18 * * *' },
        jobId: 'daily-stats-nightly',
        removeOnComplete: { count: 7 },
        removeOnFail: { count: 30 },
      }
    );
    logger.info('Scheduled nightly stats sync');
  } catch (err: any) {
    logger.warn('Failed to schedule nightly stats sync (it might be already scheduled)', { detail: err.message });
  }

  logger.info('All background workers running successfully.');

  // ── Graceful shutdown ─────────────────────────────────────────────────────
  const shutdown = async (signal: string): Promise<void> => {
    logger.info(`Graceful shutdown initiated in Worker`, { signal });

    // Force exit after 30s if graceful shutdown stalls
    const forceTimeout = setTimeout(() => {
      logger.error('Forced worker shutdown after 30s timeout');
      process.exit(1);
    }, 30_000);

    try {
      logger.info('Draining background workers...');
      await Promise.allSettled(workers.map((w) => w.close()));
      logger.info('All background workers closed cleanly.');

      await bullMqRedis.quit();
      logger.info('Redis connection closed in Worker');

      await mongoose.disconnect();
      logger.info('MongoDB connection closed in Worker');

      clearTimeout(forceTimeout);
      logger.info('Worker shutdown complete.');
      process.exit(0);
    } catch (err: any) {
      logger.error('Failed to shutdown worker cleanly', { detail: err.message });
      process.exit(1);
    }
  };

  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
}

bootstrapWorker().catch((err: Error) => {
  logger.error('Worker bootstrap failed', { detail: err.message });
  process.exit(1);
});
