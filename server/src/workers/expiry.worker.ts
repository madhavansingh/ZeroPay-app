import { Worker } from 'bullmq';
import { bullMqRedis } from '../config/redis';
import { logger } from '../config/logger';
import { expireStaleInvoices } from '../services/invoice.service';
import { expiryQueue } from '../queues/queue.definitions';

export async function startExpiryWorker(): Promise<Worker> {
  await expiryQueue.add(
    'expire-check',
    {},
    {
      repeat: { every: 60_000 },
      jobId: 'expiry-repeatable',
    }
  );

  const worker = new Worker(
    'invoice-expiry',
    async () => {
      const expired = await expireStaleInvoices();
      if (expired > 0) {
        logger.info('[expiry] Stale invoices expired', { count: expired });
      } else {
        logger.debug('[expiry] No stale invoices found');
      }
    },
    {
      connection: bullMqRedis as any,
      concurrency: 1,
    }
  );

  worker.on('active', (job) => {
    logger.debug('[expiry] Job active', { jobId: job.id ?? undefined });
  });
  worker.on('completed', (job) => {
    logger.debug('[expiry] Job completed', { jobId: job.id ?? undefined });
  });
  worker.on('failed', (job, err) => {
    logger.error('[expiry] Job failed', { jobId: job?.id ?? undefined, detail: err.message });
  });

  return worker;
}
