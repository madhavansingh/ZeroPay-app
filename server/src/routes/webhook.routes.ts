import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { requireAuth, requireMerchant } from '../middleware/auth';
import { validate } from '../middleware/validate';
import { Merchant } from '../models/Merchant';
import { ApiKey } from '../models/ApiKey';
import { WebhookSubscription, WebhookEvent } from '../models/WebhookSubscription';
import { WebhookDeliveryLog } from '../models/WebhookDeliveryLog';
import { enqueueWebhookDelivery } from '../queues/queue.definitions';
import { logger } from '../config/logger';

const router = Router();

const registerWebhookSchema = z.object({
  url: z.string().url().regex(/^https:\/\/.+/, 'URL must be a secure HTTPS endpoint'),
  events: z.array(z.enum([
    'escrow.locked', 'escrow.released', 'escrow.disputed', 'escrow.resolved',
    'invoice.created', 'invoice.paid', 'invoice.expired', 'milestone.released',
  ])).min(1, 'At least one event type is required'),
});

// ── POST /api/v1/webhooks/register ───────────────────────────────────────────
router.post('/register', requireAuth, requireMerchant, validate(registerWebhookSchema), async (req: Request, res: Response) => {
  try {
    const merchant = await Merchant.findOne({ userId: req.user._id });
    if (!merchant) {
      res.status(404).json({ success: false, error: 'Merchant profile not found' });
      return;
    }

    // Find first active API key for this merchant to associate with
    const apiKey = await ApiKey.findOne({ merchantId: merchant._id, isActive: true });
    if (!apiKey) {
      res.status(400).json({ success: false, error: 'An active developer API key is required to register webhooks' });
      return;
    }

    // Check if duplicate subscription url
    const existing = await WebhookSubscription.findOne({ merchantId: merchant._id, url: req.body.url, isActive: true });
    if (existing) {
      res.status(400).json({ success: false, error: 'A webhook subscription is already active for this URL' });
      return;
    }

    const { nanoid } = await import('nanoid');
    const secret = `whsec_${nanoid(24)}`;

    const webhook = await WebhookSubscription.create({
      merchantId: merchant._id,
      apiKeyId: apiKey._id,
      url: req.body.url,
      events: req.body.events,
      secret,
      isActive: true,
      failureCount: 0,
    });

    logger.info('Webhook registered successfully', { webhookId: webhook._id.toString(), merchantId: merchant.merchantId });

    res.status(201).json({
      success: true,
      data: {
        id: webhook._id,
        url: webhook.url,
        events: webhook.events,
        secret: webhook.secret, // Plaintext secret shown only once
        isActive: webhook.isActive,
        createdAt: webhook.createdAt,
      },
    });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : 'Webhook registration failed';
    res.status(500).json({ success: false, error: msg });
  }
});

// ── GET /api/v1/webhooks ─────────────────────────────────────────────────────
router.get('/', requireAuth, requireMerchant, async (req: Request, res: Response) => {
  try {
    const merchant = await Merchant.findOne({ userId: req.user._id });
    if (!merchant) {
      res.status(404).json({ success: false, error: 'Merchant profile not found' });
      return;
    }

    const webhooks = await WebhookSubscription.find({ merchantId: merchant._id })
      .select('-secret')
      .sort({ createdAt: -1 });

    res.json({ success: true, data: webhooks });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : 'Failed to list webhooks';
    res.status(500).json({ success: false, error: msg });
  }
});

// ── DELETE /api/v1/webhooks/:id ──────────────────────────────────────────────
router.delete('/:id', requireAuth, requireMerchant, async (req: Request, res: Response) => {
  try {
    const merchant = await Merchant.findOne({ userId: req.user._id });
    if (!merchant) {
      res.status(404).json({ success: false, error: 'Merchant profile not found' });
      return;
    }

    const result = await WebhookSubscription.findOneAndUpdate(
      { _id: req.params.id, merchantId: merchant._id },
      { $set: { isActive: false } },
      { new: true }
    );

    if (!result) {
      res.status(404).json({ success: false, error: 'Webhook subscription not found' });
      return;
    }

    logger.info('Webhook subscription deactivated', { webhookId: result._id.toString() });
    res.json({ success: true, message: 'Webhook subscription successfully deactivated' });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : 'Failed to deactivate webhook';
    res.status(500).json({ success: false, error: msg });
  }
});

// ── POST /api/v1/webhooks/:id/test ───────────────────────────────────────────
router.post('/:id/test', requireAuth, requireMerchant, async (req: Request, res: Response) => {
  try {
    const merchant = await Merchant.findOne({ userId: req.user._id });
    if (!merchant) {
      res.status(404).json({ success: false, error: 'Merchant profile not found' });
      return;
    }

    const webhook = await WebhookSubscription.findOne({ _id: req.params.id, merchantId: merchant._id, isActive: true });
    if (!webhook) {
      res.status(404).json({ success: false, error: 'Active webhook subscription not found' });
      return;
    }

    const testPayload = {
      event: 'test.ping',
      timestamp: new Date().toISOString(),
      webhookId: webhook._id.toString(),
      message: 'ZeroPay Webhook Test Event',
    };

    // Queue test webhook delivery
    await enqueueWebhookDelivery({
      webhookSubscriptionId: webhook._id.toString(),
      event: 'test.ping',
      payload: testPayload,
      attemptNumber: 1,
    });

    res.json({ success: true, message: 'Test event queued successfully' });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : 'Failed to trigger test event';
    res.status(500).json({ success: false, error: msg });
  }
});

// ── GET /api/v1/webhooks/:id/deliveries ──────────────────────────────────────
router.get('/:id/deliveries', requireAuth, requireMerchant, async (req: Request, res: Response) => {
  try {
    const merchant = await Merchant.findOne({ userId: req.user._id });
    if (!merchant) {
      res.status(404).json({ success: false, error: 'Merchant profile not found' });
      return;
    }

    const webhook = await WebhookSubscription.findOne({ _id: req.params.id, merchantId: merchant._id });
    if (!webhook) {
      res.status(404).json({ success: false, error: 'Webhook subscription not found' });
      return;
    }

    const deliveries = await WebhookDeliveryLog.find({ webhookSubscriptionId: webhook._id })
      .sort({ createdAt: -1 })
      .limit(50);

    res.json({ success: true, data: deliveries });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : 'Failed to fetch deliveries';
    res.status(500).json({ success: false, error: msg });
  }
});

// ── POST /api/v1/webhooks/deliveries/:deliveryId/replay ──────────────────────
router.post('/deliveries/:deliveryId/replay', requireAuth, requireMerchant, async (req: Request, res: Response) => {
  try {
    const merchant = await Merchant.findOne({ userId: req.user._id });
    if (!merchant) {
      res.status(404).json({ success: false, error: 'Merchant profile not found' });
      return;
    }

    const deliveryLog = await WebhookDeliveryLog.findById(req.params.deliveryId);
    if (!deliveryLog) {
      res.status(404).json({ success: false, error: 'Delivery log not found' });
      return;
    }

    const webhook = await WebhookSubscription.findOne({ _id: deliveryLog.webhookSubscriptionId, merchantId: merchant._id });
    if (!webhook) {
      res.status(404).json({ success: false, error: 'Webhook subscription not found or unauthorized' });
      return;
    }

    // Enqueue a new delivery job with same event and payload, incrementing attempt number
    await enqueueWebhookDelivery({
      webhookSubscriptionId: webhook._id.toString(),
      event: deliveryLog.event,
      payload: deliveryLog.payload as any,
      attemptNumber: deliveryLog.attemptNumber + 1,
    });

    res.json({ success: true, message: 'Webhook replay enqueued successfully' });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : 'Failed to replay webhook';
    res.status(500).json({ success: false, error: msg });
  }
});

export default router;
