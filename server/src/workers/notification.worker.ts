import { Worker, Job } from 'bullmq';
import { bullMqRedis } from '../config/redis';
import { logger } from '../config/logger';
import { sendPushToUser } from '../services/notification.service';
import type { NotificationJobData } from '../queues/queue.definitions';

async function safeNotify(userId: string, payload: { title: string; body: string; data: Record<string, string> }, ctx: object): Promise<void> {
  try {
    await sendPushToUser(userId, payload);
    logger.info('[notification] Push delivered', { ...(ctx as Record<string, unknown>), userId });
  } catch (err) {
    logger.warn('[notification] Push delivery failed — non-fatal', {
      ...(ctx as Record<string, unknown>),
      userId,
      detail: err instanceof Error ? err.message : String(err),
    });
    // Do NOT re-throw — one user failure shouldn't fail the whole job
  }
}

export function startNotificationWorker(): Worker {
  const worker = new Worker<NotificationJobData>(
    'notification-dispatch',
    async (job: Job<NotificationJobData>) => {
      const { type, merchantUserId, customerUserId, invoiceId, amountPaise, shopName } = job.data;
      const amountInr = (amountPaise / 100).toFixed(2);
      const ctx = { invoiceId, type, jobId: job.id ?? undefined };

      logger.info('[notification] Dispatching', ctx);

      if (type === 'payment-confirmed') {
        const sends: Promise<void>[] = [];
        if (merchantUserId) {
          sends.push(safeNotify(merchantUserId, {
            title: '✅ Payment Received!',
            body: `₹${amountInr} received at ${shopName}`,
            data: { type: 'payment-confirmed', invoiceId },
          }, ctx));
        }
        if (customerUserId) {
          sends.push(safeNotify(customerUserId, {
            title: '✅ Payment Confirmed',
            body: `Your payment of ₹${amountInr} to ${shopName} is confirmed`,
            data: { type: 'payment-confirmed', invoiceId },
          }, ctx));
        }
        await Promise.all(sends);
      } else if (type === 'payment-incoming') {
        if (merchantUserId) {
          await safeNotify(merchantUserId, {
            title: '💳 Payment Incoming',
            body: `₹${amountInr} payment submitted at ${shopName}`,
            data: { type: 'payment-incoming', invoiceId },
          }, ctx);
        }
      } else if (type === 'invoice-expired') {
        if (merchantUserId) {
          await safeNotify(merchantUserId, {
            title: '⏰ Invoice Expired',
            body: `Payment request for ₹${amountInr} expired`,
            data: { type: 'invoice-expired', invoiceId },
          }, ctx);
        }
      } else if (type === 'escrow-locked') {
        const sends: Promise<void>[] = [];
        if (merchantUserId) {
          sends.push(safeNotify(merchantUserId, {
            title: '🔒 Escrow Funds Locked',
            body: `₹${amountInr} locked in contract for ${shopName}`,
            data: { type: 'escrow-locked', invoiceId },
          }, ctx));
        }
        if (customerUserId) {
          sends.push(safeNotify(customerUserId, {
            title: '🔒 Escrow Funds Locked',
            body: `Your payment of ₹${amountInr} is securely locked in escrow`,
            data: { type: 'escrow-locked', invoiceId },
          }, ctx));
        }
        await Promise.all(sends);
      } else if (type === 'milestone-released') {
        const sends: Promise<void>[] = [];
        if (merchantUserId) {
          sends.push(safeNotify(merchantUserId, {
            title: '💸 Milestone Released',
            body: `Milestone payout of ₹${amountInr} released to your wallet`,
            data: { type: 'milestone-released', invoiceId },
          }, ctx));
        }
        if (customerUserId) {
          sends.push(safeNotify(customerUserId, {
            title: '💸 Milestone Released',
            body: `Approved release of milestone payout of ₹${amountInr}`,
            data: { type: 'milestone-released', invoiceId },
          }, ctx));
        }
        await Promise.all(sends);
      } else if (type === 'dispute-raised') {
        const sends: Promise<void>[] = [];
        if (merchantUserId) {
          sends.push(safeNotify(merchantUserId, {
            title: '⚠️ Escrow Disputed',
            body: `A dispute has been raised on invoice of ₹${amountInr}`,
            data: { type: 'dispute-raised', invoiceId },
          }, ctx));
        }
        if (customerUserId) {
          sends.push(safeNotify(customerUserId, {
            title: '⚠️ Escrow Disputed',
            body: `You raised a dispute on invoice of ₹${amountInr}`,
            data: { type: 'dispute-raised', invoiceId },
          }, ctx));
        }
        await Promise.all(sends);
      } else if (type === 'refund-completed') {
        const sends: Promise<void>[] = [];
        if (merchantUserId) {
          sends.push(safeNotify(merchantUserId, {
            title: '🔄 Refund Completed',
            body: `Refund of ₹${amountInr} processed for customer`,
            data: { type: 'refund-completed', invoiceId },
          }, ctx));
        }
        if (customerUserId) {
          sends.push(safeNotify(customerUserId, {
            title: '🔄 Refund Completed',
            body: `Your refund of ₹${amountInr} has been completed`,
            data: { type: 'refund-completed', invoiceId },
          }, ctx));
        }
        await Promise.all(sends);
      }

      logger.info('[notification] Dispatch complete', ctx);
    },
    {
      connection: bullMqRedis as any,
      concurrency: 10,
    }
  );

  worker.on('active', (job) => {
    logger.debug('[notification] Job active', { jobId: job.id ?? undefined });
  });
  worker.on('completed', (job) => {
    logger.info('[notification] Job completed', { jobId: job.id ?? undefined });
  });
  worker.on('failed', (job, err) => {
    logger.error('[notification] Job failed', { jobId: job?.id ?? undefined, detail: err.message });
  });

  return worker;
}
