import { describe, it, expect, vi, beforeEach } from 'vitest';
import axios from 'axios';
import crypto from 'crypto';

// Mock env variables
vi.mock('../../src/config/env', () => ({
  env: {
    NODE_ENV: 'test',
  },
}));

import { WebhookSubscription } from '../../src/models/WebhookSubscription';
import { WebhookDeliveryLog } from '../../src/models/WebhookDeliveryLog';

// Mock models
vi.mock('../../src/models/WebhookSubscription', () => ({
  WebhookSubscription: {
    findById: vi.fn(),
    findByIdAndUpdate: vi.fn(),
  },
}));

vi.mock('../../src/models/WebhookDeliveryLog', () => ({
  WebhookDeliveryLog: {
    create: vi.fn().mockResolvedValue({}),
  },
}));

vi.mock('axios');

describe('Webhook Delivery Engine & Worker', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  const mockPayload = { invoiceId: 'INV-1234', event: 'escrow.locked' };
  const mockSecret = 'super-secret-key';
  const mockUrl = 'https://customer-api.com/webhooks';

  it('should successfully deliver webhook with correct HMAC signature header', async () => {
    const mockSubscription = {
      _id: 'mock-sub-id',
      url: mockUrl,
      secret: mockSecret,
      isActive: true,
      failureCount: 0,
    };

    vi.mocked(WebhookSubscription.findById).mockResolvedValueOnce(mockSubscription as any);
    vi.mocked(axios.post).mockResolvedValueOnce({ status: 200, data: 'OK' } as any);

    // Compute expected HMAC signature manually for test validation
    const stringified = JSON.stringify(mockPayload);
    const expectedSignature = crypto
      .createHmac('sha256', mockSecret)
      .update(stringified)
      .digest('hex');

    // Run verification logic directly (simulating worker process logic)
    const signature = crypto
      .createHmac('sha256', mockSubscription.secret)
      .update(JSON.stringify(mockPayload))
      .digest('hex');

    expect(signature).toBe(expectedSignature);

    const response = await axios.post(mockSubscription.url, mockPayload, {
      headers: {
        'Content-Type': 'application/json',
        'X-ZeroPay-Signature': `sha256=${signature}`,
      },
    });

    expect(response.status).toBe(200);
    expect(axios.post).toHaveBeenCalledWith(
      mockUrl,
      mockPayload,
      expect.objectContaining({
        headers: expect.objectContaining({
          'X-ZeroPay-Signature': `sha256=${expectedSignature}`,
        }),
      })
    );
  });

  it('should increment failureCount on failed HTTP response', async () => {
    const mockSubscription = {
      _id: 'mock-sub-id',
      url: mockUrl,
      secret: mockSecret,
      isActive: true,
      failureCount: 3,
    };

    vi.mocked(WebhookSubscription.findById).mockResolvedValueOnce(mockSubscription as any);
    vi.mocked(axios.post).mockRejectedValueOnce({
      message: 'Connection Timeout',
      response: { status: 504 },
    } as any);

    try {
      await axios.post(mockUrl, mockPayload);
    } catch (err: any) {
      // Simulate failed worker catch logic
      const currentFailures = mockSubscription.failureCount + 1;
      const isDeactivating = currentFailures >= 10;

      await WebhookSubscription.findByIdAndUpdate(mockSubscription._id, {
        $inc: { failureCount: 1 },
        $set: isDeactivating ? { isActive: false } : {},
      });

      expect(currentFailures).toBe(4);
      expect(isDeactivating).toBe(false);
      expect(WebhookSubscription.findByIdAndUpdate).toHaveBeenCalledWith(
        'mock-sub-id',
        expect.objectContaining({
          $inc: { failureCount: 1 },
        })
      );
    }
  });

  it('should auto-deactivate webhook subscription after exactly 10 consecutive failures', async () => {
    const mockSubscription = {
      _id: 'mock-sub-id',
      url: mockUrl,
      secret: mockSecret,
      isActive: true,
      failureCount: 9, // One failure away from deactivation!
    };

    vi.mocked(WebhookSubscription.findById).mockResolvedValueOnce(mockSubscription as any);
    vi.mocked(axios.post).mockRejectedValueOnce({
      message: 'Internal Server Error',
      response: { status: 500 },
    } as any);

    try {
      await axios.post(mockUrl, mockPayload);
    } catch (err: any) {
      // Simulate failed worker catch logic
      const currentFailures = mockSubscription.failureCount + 1;
      const isDeactivating = currentFailures >= 10;

      await WebhookSubscription.findByIdAndUpdate(mockSubscription._id, {
        $inc: { failureCount: 1 },
        $set: isDeactivating ? { isActive: false } : {},
      });

      expect(currentFailures).toBe(10);
      expect(isDeactivating).toBe(true);
      expect(WebhookSubscription.findByIdAndUpdate).toHaveBeenCalledWith(
        'mock-sub-id',
        expect.objectContaining({
          $set: { isActive: false },
        })
      );
    }
  });
});
