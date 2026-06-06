import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { requireAuth } from '../middleware/auth';
import { validate } from '../middleware/validate';
import { paymentRateLimit } from '../middleware/rateLimit';
import { Invoice } from '../models/Invoice';
import { Transaction } from '../models/Transaction';
import { Merchant } from '../models/Merchant';
import { buildPaymentTx } from '../services/mesh.service';
import { transitionInvoiceStatus, injectChatMessage } from '../services/invoice.service';
import { enqueueNotification, enqueueTxConfirmation } from '../queues/queue.definitions';

const router = Router();

const buildTxSchema = z.object({
  invoiceId: z.string().min(1),
  customerAddress: z.string().regex(/^addr(_test)?1[a-z0-9]+$/, 'Invalid customer address format'),
});

const submitTxSchema = z.object({
  invoiceId: z.string().min(1),
  txHash: z.string().regex(/^[a-f0-9]{64}$/, 'Invalid txHash format'),
});

// POST /api/v1/payments/build-tx
router.post(
  '/build-tx',
  requireAuth,
  validate(buildTxSchema),
  async (req: Request, res: Response): Promise<void> => {
    try {
      const { invoiceId, customerAddress } = req.body as z.infer<typeof buildTxSchema>;
      const result = await buildPaymentTx(invoiceId, customerAddress);
      res.json({ success: true, data: result });
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'TX build failed';
      res.status(400).json({ success: false, error: message });
    }
  }
);

// POST /api/v1/payments/submit
router.post(
  '/submit',
  requireAuth,
  paymentRateLimit,
  validate(submitTxSchema),
  async (req: Request, res: Response): Promise<void> => {
    try {
      const { invoiceId, txHash } = req.body as z.infer<typeof submitTxSchema>;

      const invoice = await Invoice.findOne({ invoiceId });
      if (!invoice) {
        res.status(404).json({ success: false, error: 'Invoice not found' });
        return;
      }

      if (invoice.status !== 'pending') {
        res.status(409).json({
          success: false,
          error: `Invoice is already ${invoice.status}`,
        });
        return;
      }

      if (invoice.expiresAt < new Date()) {
        res.status(410).json({ success: false, error: 'Invoice has expired' });
        return;
      }

      // Check for duplicate txHash (deduplication guard)
      const existingTx = await Transaction.findOne({ txHash });
      if (existingTx) {
        res.status(409).json({ success: false, error: 'Transaction already submitted' });
        return;
      }

      const merchant = await Merchant.findById(invoice.merchantId);

      // Atomically transition to submitted
      const updated = await transitionInvoiceStatus(invoiceId, 'pending', 'submitted', {
        txHash,
      });

      if (!updated) {
        res.status(409).json({ success: false, error: 'Invoice status changed concurrently' });
        return;
      }

      // Create transaction record
      await Transaction.create({
        txHash,
        invoiceId: invoice._id,
        invoiceStringId: invoiceId,
        merchantId: invoice.merchantId,
        amountLovelaceExpected: invoice.amountLovelace,
        status: 'submitted',
      });

      // Inject submitted message into chat room
      if (invoice.chatRoomId) {
        await injectChatMessage(invoice.chatRoomId, 'payment-submitted', {
          invoiceId,
          txHash,
          amountPaise: invoice.amountPaise,
          amountLovelace: invoice.amountLovelace,
          submittedAt: new Date().toISOString(),
        });
      }

      // Enqueue confirmation polling
      await enqueueTxConfirmation({
        invoiceId,
        txHash,
        merchantId: invoice.merchantId.toString(),
        customerId: invoice.customerId?.toString(),
        amountLovelace: invoice.amountLovelace,
        paymentAddress: invoice.paymentAddress,
      });

      // Notify merchant immediately
      if (merchant?.userId) {
        await enqueueNotification({
          type: 'payment-incoming',
          merchantUserId: merchant.userId.toString(),
          invoiceId,
          amountPaise: invoice.amountPaise,
          shopName: merchant.shopName,
        });
      }

      res.json({
        success: true,
        data: {
          invoiceId,
          txHash,
          status: 'submitted',
          message: 'Payment received — confirming on Cardano blockchain',
        },
      });
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Payment submission failed';
      res.status(400).json({ success: false, error: message });
    }
  }
);

export default router;
