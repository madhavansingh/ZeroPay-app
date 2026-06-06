import { Worker, Job } from 'bullmq';
import axios from 'axios';
import crypto from 'crypto';
import { bullMqRedis } from '../config/redis';
import { logger } from '../config/logger';
import { WebhookSubscription } from '../models/WebhookSubscription';
import { WebhookDeliveryLog } from '../models/WebhookDeliveryLog';
import type { WebhookDeliveryJobData } from '../queues/queue.definitions';

export function startWebhookDeliveryWorker(): Worker {
  const worker = new Worker<WebhookDeliveryJobData>(
    'webhook-delivery',
    async (job: Job<WebhookDeliveryJobData>) => {
      const { webhookSubscriptionId, event, payload, attemptNumber } = job.data;
      const ctx = { webhookSubscriptionId, event, attemptNumber, jobId: job.id ?? undefined };

      const subscription = await WebhookSubscription.findById(webhookSubscriptionId);
      if (!subscription) {
        logger.warn('[webhook-worker] Subscription not found — skipping', ctx);
        return;
      }

      if (!subscription.isActive) {
        logger.debug('[webhook-worker] Subscription is inactive — skipping', ctx);
        return;
      }

      const start = Date.now();
      const stringifiedPayload = JSON.stringify(payload);
      const signature = crypto
        .createHmac('sha256', subscription.secret)
        .update(stringifiedPayload)
        .digest('hex');

      try {
        const response = await axios.post(
          subscription.url,
          payload,
          {
            headers: {
              'Content-Type': 'application/json',
              'X-ZeroPay-Signature': `sha256=${signature}`,
              'User-Agent': 'ZeroPay-Webhook-Engine/1.0',
            },
            timeout: 10000, // 10-second timeout
          }
        );

        const latencyMs = Date.now() - start;

        // Log successful delivery
        await WebhookDeliveryLog.create({
          webhookSubscriptionId: subscription._id,
          event,
          url: subscription.url,
          payload,
          statusCode: response.status,
          latencyMs,
          responseBody: typeof response.data === 'string'
            ? response.data.slice(0, 1000)
            : JSON.stringify(response.data).slice(0, 1000),
          attemptNumber,
          success: true,
        });

        // Reset failure count and update lastDeliveredAt
        await WebhookSubscription.findByIdAndUpdate(subscription._id, {
          $set: { failureCount: 0, lastDeliveredAt: new Date() },
        });

        logger.info('[webhook-worker] Webhook delivered successfully', {
          ...ctx,
          url: subscription.url,
          latencyMs,
          statusCode: response.status,
        });
      } catch (err: any) {
        const latencyMs = Date.now() - start;
        const statusCode = err.response?.status;
        const errorMsg = err.response?.data
          ? (typeof err.response.data === 'string' ? err.response.data : JSON.stringify(err.response.data)).slice(0, 1000)
          : err.message;

        // Log failed attempt
        await WebhookDeliveryLog.create({
          webhookSubscriptionId: subscription._id,
          event,
          url: subscription.url,
          payload,
          statusCode,
          latencyMs,
          error: errorMsg,
          attemptNumber,
          success: false,
        });

        // Increment failure count
        const currentFailures = subscription.failureCount + 1;
        const isDeactivating = currentFailures >= 10;

        await WebhookSubscription.findByIdAndUpdate(subscription._id, {
          $inc: { failureCount: 1 },
          $set: isDeactivating ? { isActive: false } : {},
        });

        logger.warn('[webhook-worker] Webhook delivery failed', {
          ...ctx,
          url: subscription.url,
          failures: currentFailures,
          deactivated: isDeactivating,
          error: errorMsg,
        });

        throw err; // Throwing triggers BullMQ's built-in exponential backoff retry schedule
      }
    },
    {
      connection: bullMqRedis as any,
      concurrency: 5,
    }
  );

  worker.on('active', (job) => {
    logger.debug('[webhook-worker] Job active', { jobId: job.id ?? undefined, subscriptionId: job.data.webhookSubscriptionId });
  });

  worker.on('completed', (job) => {
    logger.info('[webhook-worker] Job completed', { jobId: job.id ?? undefined, subscriptionId: job.data.webhookSubscriptionId });
  });

  worker.on('failed', (job, err) => {
    if (job) {
      logger.error('[webhook-worker] Job failed permanently', {
        jobId: job.id ?? undefined,
        subscriptionId: job.data.webhookSubscriptionId,
        detail: err.message,
      });
    }
  });

  return worker;
}
