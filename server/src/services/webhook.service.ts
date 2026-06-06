import { WebhookSubscription } from '../models/WebhookSubscription';
import { enqueueWebhookDelivery } from '../queues/queue.definitions';
import { logger } from '../config/logger';

export async function triggerWebhooks(
  merchantId: string,
  event: string,
  payload: Record<string, unknown>
): Promise<void> {
  try {
    const subscriptions = await WebhookSubscription.find({
      merchantId,
      events: event,
      isActive: true,
    });

    if (subscriptions.length === 0) return;

    logger.debug('[webhook-service] Enqueuing webhooks for event', { merchantId, event, count: subscriptions.length });

    await Promise.all(
      subscriptions.map((sub) =>
        enqueueWebhookDelivery({
          webhookSubscriptionId: sub._id.toString(),
          event,
          payload: {
            event,
            webhookSubscriptionId: sub._id.toString(),
            timestamp: new Date().toISOString(),
            data: payload,
          },
          attemptNumber: 1,
        })
      )
    );
  } catch (err: any) {
    logger.error('[webhook-service] Failed to trigger webhooks:', { merchantId, event, error: err.message });
  }
}
