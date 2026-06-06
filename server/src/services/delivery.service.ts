import crypto from 'crypto';
import { env } from '../config/env';
import { Invoice } from '../models/Invoice';
import { Product } from '../models/Product';
import { DigitalDelivery } from '../models/DigitalDelivery';
import { User } from '../models/User';
import { sendPushToUser } from './notification.service';
import { getFirebaseDatabase } from '../config/firebase-admin';
import { logger } from '../config/logger';

export async function processDigitalDelivery(invoiceId: string): Promise<void> {
  const ctx = { invoiceId };
  logger.info('[delivery] Starting digital delivery processing', ctx);

  try {
    const invoice = await Invoice.findOne({ invoiceId });
    if (!invoice) {
      logger.warn('[delivery] Invoice not found', ctx);
      return;
    }

    if (!invoice.productId) {
      logger.debug('[delivery] Invoice has no associated product — skipping', ctx);
      return;
    }

    const product = await Product.findById(invoice.productId);
    if (!product) {
      logger.warn('[delivery] Product not found for invoice', { ...ctx, productId: invoice.productId.toString() });
      return;
    }

    if (!product.isDigital || !product.ipfsHash) {
      logger.debug('[delivery] Product is not digital or missing IPFS hash — skipping', { ...ctx, productId: product._id.toString() });
      return;
    }

    // 1. Generate 48h time-limited signed URL using built-in crypto HMAC
    const expiresAt = new Date(Date.now() + 48 * 60 * 60 * 1000); // 48 hours
    const expiryTimestamp = Math.floor(expiresAt.getTime() / 1000);
    const message = `${product.ipfsHash}:${expiryTimestamp}`;
    const hmac = crypto
      .createHmac('sha256', env.PINATA_JWT)
      .update(message)
      .digest('hex');

    const signedUrl = `https://gateway.pinata.cloud/ipfs/${product.ipfsHash}?expires=${expiryTimestamp}&signature=${hmac}`;

    // 2. Persist DigitalDelivery record
    const delivery = await DigitalDelivery.create({
      invoiceId: invoice.invoiceId,
      productId: product._id,
      customerId: invoice.customerId,
      ipfsHash: product.ipfsHash,
      signedUrl,
      expiresAt,
      downloadCount: 0,
      status: 'delivered',
    });

    // 3. Increment product totalSold
    product.totalSold = (product.totalSold || 0) + 1;
    await product.save();

    // 4. Send Firebase RTDB Realtime Notification
    if (invoice.customerId) {
      const customer = await User.findById(invoice.customerId);
      if (customer) {
        try {
          const db = getFirebaseDatabase();
          const notificationRef = db.ref(`/users/${customer._id}/notifications`).push();
          
          await notificationRef.set({
            title: '📦 Digital Product Delivered',
            body: `Your digital product "${product.title}" is ready for download!`,
            data: {
              type: 'digital-delivery',
              invoiceId: invoice.invoiceId,
              signedUrl,
              deliveryId: delivery._id.toString(),
            },
            createdAt: Date.now(),
            read: false,
          });

          logger.info('[delivery] RTDB notification updated', { ...ctx, customerId: customer._id.toString() });
        } catch (e: any) {
          logger.warn('[delivery] RTDB notification write failed — non-fatal', { ...ctx, detail: e.message });
        }

        // 5. Send Push Notification
        await sendPushToUser(customer._id.toString(), {
          title: '📦 Digital Product Delivered',
          body: `Your download link for "${product.title}" is ready!`,
          data: {
            type: 'digital-delivery',
            invoiceId: invoice.invoiceId,
            signedUrl,
          },
        });
      }
    }

    logger.info('[delivery] Digital delivery processed successfully', {
      ...ctx,
      deliveryId: delivery._id.toString(),
      productId: product.productId,
    });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : 'Unknown error';
    logger.error('[delivery] Digital delivery processing failed', { ...ctx, detail: msg });
    throw err; // Allow BullMQ queue retries
  }
}
