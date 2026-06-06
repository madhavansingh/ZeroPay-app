import { Worker, Job } from 'bullmq';
import { bullMqRedis } from '../config/redis';
import { requestContext } from '../config/context';
import { randomUUID } from 'crypto';
import { env } from '../config/env';
import { logger } from '../config/logger';
import { Invoice } from '../models/Invoice';
import { Transaction } from '../models/Transaction';
import { getTxInfo, verifyPayment } from '../services/blockchain.service';
import { transitionInvoiceStatus } from '../services/invoice.service';
import { enqueueReceipt, enqueueNotification, TxConfirmationJobData } from '../queues/queue.definitions';
import { Merchant } from '../models/Merchant';
import { ESCROW_SCRIPT_ADDRESS } from '../services/escrow.service';
import { updateMerchantReputation } from '../services/reputation.service';

const MIN_CONFIRMATIONS = env.MIN_CONFIRMATIONS;
const HIGH_VALUE_THRESHOLD_USD = env.HIGH_VALUE_THRESHOLD_USD;
const HIGH_VALUE_CONFIRMATIONS = env.HIGH_VALUE_CONFIRMATIONS;

export function startConfirmationWorker(): Worker {
  const worker = new Worker<TxConfirmationJobData>(
    'tx-confirmation',
    async (job: Job<TxConfirmationJobData>) => {
      const { invoiceId, txHash, amountLovelace, paymentAddress } = job.data;
      const correlationId = `job-confirmation-${job.id ?? randomUUID()}`;

      return requestContext.run({ correlationId, invoiceId }, async () => {
        const ctx = { invoiceId, txHash, jobId: job.id ?? undefined, attempt: job.attemptsMade };

      // Verify invoice is still in a pollable state
      const invoice = await Invoice.findOne({ invoiceId });
      if (!invoice) {
        logger.warn('[confirmation] Invoice not found — skipping', ctx);
        return;
      }
      if (!['submitted', 'confirming'].includes(invoice.status)) {
        logger.info('[confirmation] Invoice in terminal state — no action', { ...ctx, status: invoice.status });
        return;
      }

      // Fetch tx from chain (Blockfrost → Koios fallback)
      let txInfo;
      try {
        txInfo = await getTxInfo(txHash);
      } catch (err) {
        logger.warn('[confirmation] Chain query failed — will retry', { ...ctx, detail: err instanceof Error ? err.message : String(err) });
        throw err; // BullMQ will retry
      }

      if (!txInfo) {
        // Tx not found — still in mempool or invalid
        await Transaction.findOneAndUpdate(
          { txHash },
          { $inc: { pollingAttempts: 1 }, $set: { lastPolledAt: new Date() } }
        );
        logger.debug('[confirmation] TX not found on chain — retrying', ctx);
        throw new Error(`TX ${txHash} not found on chain — retrying`);
      }

      // Determine required confirmations (high-value check)
      const adaValue = amountLovelace / 1_000_000;
      const requiredConfirmations =
        adaValue * 0.4 > HIGH_VALUE_THRESHOLD_USD
          ? HIGH_VALUE_CONFIRMATIONS
          : MIN_CONFIRMATIONS;

      const { confirmations } = txInfo;

      logger.debug('[confirmation] Polling cycle', { ...ctx, confirmations, requiredConfirmations });

      // Update transaction record
      await Transaction.findOneAndUpdate(
        { txHash },
        {
          $set: {
            blockHeight: txInfo.blockHeight,
            blockHash: txInfo.blockHash,
            slot: txInfo.slot,
            networkConfirmations: confirmations,
            lastPolledAt: new Date(),
            status: confirmations >= requiredConfirmations ? 'confirmed' : 'confirming',
          },
          $inc: { pollingAttempts: 1 },
        }
      );

      // Transition to "confirming" after first on-chain detection
      if (invoice.status === 'submitted' && confirmations >= 1) {
        await transitionInvoiceStatus(invoiceId, 'submitted', 'confirming', {
          networkConfirmations: confirmations,
        });
        await job.updateProgress(1);
        logger.info('[confirmation] TX detected on chain — transitioning to confirming', ctx);
      }

      // Not yet enough confirmations — retry
      if (confirmations < requiredConfirmations) {
        throw new Error(`${confirmations}/${requiredConfirmations} confirmations — polling again`);
      }

      // Check for retry exhaustion
      if (job.attemptsMade >= 59) {
        logger.error('[confirmation] Retry exhaustion — giving up', { ...ctx, confirmations, requiredConfirmations });
        return;
      }

      // ── Confirmed! ────────────────────────────────────────────────────────
      const isEscrow = invoice.escrowState && invoice.escrowState !== 'None';
      const expectedAddress = isEscrow ? ESCROW_SCRIPT_ADDRESS : paymentAddress;
      const expectedAmount = isEscrow ? (invoice.amountLovelace + env.ESCROW_PLATFORM_FEE_LOVELACE) : amountLovelace;

      const verificationResult = verifyPayment(txInfo, expectedAddress, expectedAmount);

      await Transaction.findOneAndUpdate(
        { txHash },
        {
          $set: {
            status: 'confirmed',
            networkConfirmations: confirmations,
            amountLovelaceVerified: txInfo.totalOutputLovelace,
            verificationResult,
            confirmedAt: new Date(),
          },
        }
      );

      const confirmedInvoice = await transitionInvoiceStatus(
        invoiceId,
        invoice.status as 'submitted' | 'confirming',
        'confirmed',
        {
          amountLovelaceVerified: txInfo.totalOutputLovelace,
          verificationResult,
          networkConfirmations: confirmations,
        }
      );

      if (!confirmedInvoice) {
        logger.warn('[confirmation] Race condition detected — concurrent update won, skipping', ctx);
        return;
      }

      // Trigger reputation recalculation asynchronously
      updateMerchantReputation(confirmedInvoice.merchantId.toString()).catch((err) =>
        logger.error('[reputation] Async trigger failed in confirmation worker', { error: err.message })
      );

      const merchant = await Merchant.findById(confirmedInvoice.merchantId);

      await Promise.all([
        enqueueReceipt({ invoiceId, txHash }),
        enqueueNotification({
          type: 'payment-confirmed',
          merchantUserId: merchant?.userId?.toString(),
          customerUserId: confirmedInvoice.customerId?.toString(),
          invoiceId,
          amountPaise: confirmedInvoice.amountPaise,
          shopName: merchant?.shopName ?? 'Unknown',
        }),
      ]);

      logger.info('[confirmation] Invoice confirmed', { ...ctx, confirmations, shopName: merchant?.shopName });
      });
    },
    {
      connection: bullMqRedis as any,
      concurrency: 10,
      stalledInterval: 30_000,
      maxStalledCount: 3,
    }
  );

  worker.on('active', (job) => {
    logger.debug('[confirmation] Job active', { jobId: job.id ?? undefined, invoiceId: job.data.invoiceId });
  });

  worker.on('completed', (job) => {
    logger.info('[confirmation] Job completed', { jobId: job.id ?? undefined, invoiceId: job.data.invoiceId });
  });

  worker.on('failed', (job, err) => {
    if (job && !err.message.includes('not found on chain') && !err.message.includes('confirmations')) {
      logger.error('[confirmation] Job failed permanently', { jobId: job.id ?? undefined, invoiceId: job.data.invoiceId, detail: err.message });
    }
  });

  return worker;
}
