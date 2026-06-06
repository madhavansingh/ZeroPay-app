import { Queue, QueueOptions } from 'bullmq';
import { bullMqRedis } from '../config/redis';

const defaultQueueOptions: QueueOptions = {
  connection: bullMqRedis as any,
  defaultJobOptions: {
    removeOnComplete: { count: 100 },
    removeOnFail: { count: 500 },
  },
};

// ─── Queue definitions ────────────────────────────────────────────────────────

export const txConfirmationQueue = new Queue('tx-confirmation', {
  ...defaultQueueOptions,
  defaultJobOptions: {
    ...defaultQueueOptions.defaultJobOptions,
    attempts: 60,          // ~20 minutes with 20s delay
    backoff: { type: 'fixed', delay: 20_000 },
    delay: 20_000,         // first check after 20s
  },
});

export const receiptQueue = new Queue('receipt-generation', {
  ...defaultQueueOptions,
  defaultJobOptions: {
    ...defaultQueueOptions.defaultJobOptions,
    attempts: 3,
    backoff: { type: 'exponential', delay: 30_000 },
  },
});

export const notificationQueue = new Queue('notification-dispatch', {
  ...defaultQueueOptions,
  defaultJobOptions: {
    ...defaultQueueOptions.defaultJobOptions,
    attempts: 3,
    backoff: { type: 'fixed', delay: 5_000 },
  },
});

export const expiryQueue = new Queue('invoice-expiry', {
  ...defaultQueueOptions,
});

export const dailyStatsQueue = new Queue('daily-stats', {
  ...defaultQueueOptions,
});

export const reconciliationQueue = new Queue('escrow-reconciliation', {
  ...defaultQueueOptions,
});

export const disputeResolutionQueue = new Queue('dispute-resolution', {
  ...defaultQueueOptions,
  defaultJobOptions: {
    ...defaultQueueOptions.defaultJobOptions,
    attempts: 3,
    backoff: { type: 'exponential', delay: 10_000 },
  },
});

export const webhookQueue = new Queue('webhook-delivery', {
  ...defaultQueueOptions,
  defaultJobOptions: {
    ...defaultQueueOptions.defaultJobOptions,
    attempts: 5,
    backoff: { type: 'exponential', delay: 1_000 },
  },
});

export const digitalDeliveryQueue = new Queue('digital-delivery', {
  ...defaultQueueOptions,
  defaultJobOptions: {
    ...defaultQueueOptions.defaultJobOptions,
    attempts: 3,
    backoff: { type: 'exponential', delay: 5_000 },
  },
});

export const storefrontIndexQueue = new Queue('storefront-index', {
  ...defaultQueueOptions,
});


// ─── Job payload types ────────────────────────────────────────────────────────

export interface TxConfirmationJobData {
  invoiceId: string;
  txHash: string;
  merchantId: string;
  customerId?: string;
  amountLovelace: number;
  paymentAddress: string;
}

export interface ReceiptJobData {
  invoiceId: string;
  txHash: string;
}

export interface NotificationJobData {
  type:
    | 'payment-confirmed'
    | 'invoice-expired'
    | 'payment-incoming'
    | 'escrow-locked'
    | 'milestone-released'
    | 'dispute-raised'
    | 'refund-completed';
  merchantUserId?: string;
  customerUserId?: string;
  invoiceId: string;
  amountPaise: number;
  shopName: string;
}

export interface DisputeResolutionJobData {
  invoiceId: string;
  chatRoomId?: string;
  totalLovelace: number;
  merchantId: string;
  customerId: string;
}

export interface WebhookDeliveryJobData {
  webhookSubscriptionId: string;
  event: string;
  payload: Record<string, unknown>;
  attemptNumber: number;
}

export interface DigitalDeliveryJobData {
  invoiceId: string;
  productId: string;
  customerId: string;
  ipfsHash: string;
}

export interface StorefrontIndexJobData {
  merchantId: string;
  action: 'update' | 'delete';
}

// ─── Enqueue helpers ──────────────────────────────────────────────────────────

export async function enqueueTxConfirmation(data: TxConfirmationJobData): Promise<void> {
  await txConfirmationQueue.add('confirm', data, {
    jobId: `confirm:${data.invoiceId}`,
  });
}

export async function enqueueReceipt(data: ReceiptJobData): Promise<void> {
  await receiptQueue.add('generate', data, {
    jobId: `receipt:${data.invoiceId}`,
  });
}

export async function enqueueNotification(data: NotificationJobData): Promise<void> {
  await notificationQueue.add('dispatch', data);
}

export async function enqueueDisputeResolution(data: DisputeResolutionJobData): Promise<void> {
  await disputeResolutionQueue.add('resolve', data, {
    jobId: `dispute:${data.invoiceId}`,
  });
}

export async function enqueueWebhookDelivery(data: WebhookDeliveryJobData): Promise<void> {
  await webhookQueue.add('deliver', data);
}

export async function enqueueDigitalDelivery(data: DigitalDeliveryJobData): Promise<void> {
  await digitalDeliveryQueue.add('deliver', data, {
    jobId: `delivery:${data.invoiceId}`,
  });
}

export async function enqueueStorefrontIndex(data: StorefrontIndexJobData): Promise<void> {
  await storefrontIndexQueue.add('index', data);
}
