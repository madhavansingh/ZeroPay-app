import { Worker, Job } from 'bullmq';
import { bullMqRedis } from '../config/redis';
import { logger } from '../config/logger';
import { processDigitalDelivery } from '../services/delivery.service';
import type { DigitalDeliveryJobData } from '../queues/queue.definitions';

export function startDigitalDeliveryWorker(): Worker {
  const worker = new Worker<DigitalDeliveryJobData>(
    'digital-delivery',
    async (job: Job<DigitalDeliveryJobData>) => {
      const { invoiceId, productId } = job.data;
      const ctx = { invoiceId, productId, jobId: job.id ?? undefined };

      logger.info('[digital-delivery-worker] Processing job', ctx);
      await processDigitalDelivery(invoiceId);
    },
    {
      connection: bullMqRedis as any,
      concurrency: 5,
    }
  );

  worker.on('active', (job) => {
    logger.debug('[digital-delivery-worker] Job active', { jobId: job.id ?? undefined, invoiceId: job.data.invoiceId });
  });

  worker.on('completed', (job) => {
    logger.info('[digital-delivery-worker] Job completed successfully', { jobId: job.id ?? undefined, invoiceId: job.data.invoiceId });
  });

  worker.on('failed', (job, err) => {
    if (job) {
      logger.error('[digital-delivery-worker] Job failed', {
        jobId: job.id ?? undefined,
        invoiceId: job.data.invoiceId,
        detail: err.message,
      });
    }
  });

  return worker;
}
