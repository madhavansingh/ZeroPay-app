import { Worker, Job } from 'bullmq';
import axios from 'axios';
import { bullMqRedis } from '../config/redis';
import { env } from '../config/env';
import { logger } from '../config/logger';
import { Invoice } from '../models/Invoice';
import { Merchant } from '../models/Merchant';
import { User } from '../models/User';
import { transitionInvoiceStatus, injectChatMessage } from '../services/invoice.service';
import type { ReceiptJobData } from '../queues/queue.definitions';
import type { IpfsReceipt } from '@zeropay/shared-types';

// CID validation: supports CIDv0 (Qm..., 46 chars) and CIDv1 (bafy...)
const CID_V0_REGEX = /^Qm[1-9A-HJ-NP-Za-km-z]{44}$/;
const CID_V1_REGEX = /^bafy[a-zA-Z0-9]{50,}$/;

function isValidCid(cid: string): boolean {
  return CID_V0_REGEX.test(cid) || CID_V1_REGEX.test(cid);
}

import { circuitRegistry } from '../config/circuitBreaker';

async function pinReceiptToIPFS(receipt: IpfsReceipt): Promise<string> {
  const breaker = circuitRegistry.getOrCreate('pinata');
  return breaker.execute(
    async () => {
      const response = await axios.post<{ IpfsHash: string }>(
        'https://api.pinata.cloud/pinning/pinJSONToIPFS',
        {
          pinataContent: receipt,
          pinataMetadata: {
            name: `zeropay-receipt-${receipt.invoiceId}`,
            keyvalues: {
              invoiceId: receipt.invoiceId,
              txHash: receipt.txHash,
            },
          },
        },
        {
          headers: {
            Authorization: `Bearer ${env.PINATA_JWT}`,
            'Content-Type': 'application/json',
          },
          timeout: 30_000,
        }
      );
      return response.data.IpfsHash;
    },
    (err) => {
      logger.error('[receipt] Pinata circuit breaker triggered or failed', { error: err.message });
      throw err;
    }
  );
}

export function startReceiptWorker(): Worker {
  const worker = new Worker<ReceiptJobData>(
    'receipt-generation',
    async (job: Job<ReceiptJobData>) => {
      const { invoiceId, txHash } = job.data;
      const ctx = { invoiceId, txHash, jobId: job.id ?? undefined };

      const invoice = await Invoice.findOne({ invoiceId })
        .populate('merchantId')
        .populate('customerId');

      if (!invoice) throw new Error(`Invoice ${invoiceId} not found`);
      if (invoice.status !== 'confirmed') {
        logger.info('[receipt] Invoice not confirmed — skipping', { ...ctx, status: invoice.status });
        return;
      }

      // ── Idempotency guard: skip if receipt already pinned ──────────────────
      if (invoice.receiptCid && isValidCid(invoice.receiptCid)) {
        logger.info('[receipt] Receipt already pinned — skipping duplicate upload', { ...ctx, existingCid: invoice.receiptCid });
        return;
      }

      const merchant = await Merchant.findById(invoice.merchantId);
      if (!merchant) throw new Error(`Merchant not found for invoice ${invoiceId}`);

      const customer = invoice.customerId
        ? await User.findById(invoice.customerId)
        : null;

      const receipt: IpfsReceipt = {
        version: '1.0',
        invoiceId: invoice.invoiceId,
        txHash,
        amountLovelace: invoice.amountLovelace,
        amountInr: invoice.amountPaise / 100,
        adaInrRate: invoice.adaInrRate,
        merchant: {
          merchantId: merchant.merchantId,
          shopName: merchant.shopName,
          paymentAddress: merchant.paymentAddress,
        },
        customer: {
          displayName: customer?.displayName ?? 'Anonymous',
          walletAddress: customer?.walletAddress,
        },
        confirmedAt: invoice.confirmedAt?.toISOString() ?? new Date().toISOString(),
        settledAt: new Date().toISOString(),
        networkConfirmations: invoice.networkConfirmations ?? 3,
        ...(invoice.escrowState && invoice.escrowState !== 'None' ? {
          escrow: {
            escrowState: invoice.escrowState,
            milestoneIndex: invoice.milestoneIndex,
            totalMilestones: invoice.totalMilestones,
            isDisputed: invoice.isDisputed,
            milestones: invoice.milestones.map((m) => ({
              title: m.title,
              amountLovelace: m.amountLovelace,
              status: m.status,
              releasedAt: m.releasedAt?.toISOString(),
            })),
            agreementHash: invoice.agreementHash,
            metadataHash: invoice.metadataHash,
          },
        } : {}),
      };

      logger.info('[receipt] Pinning receipt to IPFS', ctx);
      const cid = await pinReceiptToIPFS(receipt);

      // ── CID validation ────────────────────────────────────────────────────
      if (!isValidCid(cid)) {
        throw new Error(`Invalid CID returned from Pinata: "${cid}" — will retry`);
      }

      await transitionInvoiceStatus(invoiceId, 'confirmed', 'settled', {
        receiptCid: cid,
        receiptPending: false,
      });

      await Merchant.findByIdAndUpdate(merchant._id, {
        $inc: {
          totalReceivedLovelace: invoice.amountLovelace,
          totalOrders: 1,
        },
      });

      if (invoice.chatRoomId) {
        await injectChatMessage(invoice.chatRoomId, 'receipt', {
          invoiceId,
          txHash,
          amountPaise: invoice.amountPaise,
          amountLovelace: invoice.amountLovelace,
          receiptCid: cid,
          ipfsUrl: `https://gateway.pinata.cloud/ipfs/${cid}`,
          settledAt: new Date().toISOString(),
        });
      }

      logger.info('[receipt] Invoice settled', { ...ctx, cid });
    },
    {
      connection: bullMqRedis as any,
      concurrency: 10,
    }
  );

  worker.on('active', (job) => {
    logger.debug('[receipt] Job active', { jobId: job.id ?? undefined, invoiceId: job.data.invoiceId });
  });

  worker.on('completed', (job) => {
    logger.info('[receipt] Job completed', { jobId: job.id ?? undefined, invoiceId: job.data.invoiceId });
  });

  worker.on('failed', async (job, err) => {
    if (job) {
      logger.error('[receipt] Job failed', { jobId: job.id ?? undefined, invoiceId: job.data.invoiceId, detail: err.message });
      await Invoice.findOneAndUpdate(
        { invoiceId: job.data.invoiceId },
        { $set: { receiptPending: true } }
      );
    }
  });

  return worker;
}
