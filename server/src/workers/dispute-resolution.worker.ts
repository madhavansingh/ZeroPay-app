import { Worker, Job } from 'bullmq';
import { bullMqRedis } from '../config/redis';
import { logger } from '../config/logger';
import { Invoice } from '../models/Invoice';
import { DisputeVerdict } from '../models/DisputeVerdict';
import { summarizeDispute } from '../services/ai.service';
import { buildAdminResolveTx } from '../services/escrow.service';
import { enqueueNotification } from '../queues/queue.definitions';
import { Merchant } from '../models/Merchant';
import type { DisputeResolutionJobData } from '../queues/queue.definitions';

const AUTO_DISPUTE_THRESHOLD_LOVELACE = 20_000_000; // ≈10 ADA

export function startDisputeResolutionWorker(): Worker {
  const worker = new Worker<DisputeResolutionJobData>(
    'dispute-resolution',
    async (job: Job<DisputeResolutionJobData>) => {
      const { invoiceId } = job.data;
      const ctx = { invoiceId, jobId: job.id ?? undefined };

      logger.info('[dispute-worker] Beginning AI arbitration pipeline', ctx);

      const invoice = await Invoice.findOne({ invoiceId });
      if (!invoice) {
        logger.warn('[dispute-worker] Invoice not found — skipping', ctx);
        return;
      }

      if (invoice.escrowState !== 'Disputed') {
        logger.debug('[dispute-worker] Escrow is not disputed — skipping', { ...ctx, escrowState: invoice.escrowState });
        return;
      }

      // Check if verdict already exists to prevent duplicate runs
      const existing = await DisputeVerdict.findOne({ invoiceId });
      if (existing) {
        logger.info('[dispute-worker] Verdict already exists — skipping AI pipeline', ctx);
        return;
      }

      try {
        // 1. Gather chat history + evidence CIDs, and call Gemini summary engine
        const summary = await summarizeDispute(invoiceId);

        // 2. Determine confidence and threshold limits
        const confidence = 0.90; // High AI trust default
        const isLowValue = invoice.amountLovelace < AUTO_DISPUTE_THRESHOLD_LOVELACE;
        const canAutoExecute = isLowValue && confidence >= 0.80;

        const autoExecAt = canAutoExecute
          ? new Date(Date.now() + 24 * 60 * 60 * 1000) // Auto-execute in 24h
          : undefined;

        // 3. Persist DisputeVerdict
        const verdict = await DisputeVerdict.create({
          invoiceId,
          merchantSplitPercent: summary.recommendedSplitMerchantPercent,
          customerSplitPercent: summary.recommendedSplitCustomerPercent,
          confidence,
          reasoning: summary.reasoning,
          keyClaims: summary.keyClaims,
          status: canAutoExecute ? 'auto_queued' : 'pending',
          autoExecAt,
          humanReviewRequired: !canAutoExecute,
        });

        logger.info('[dispute-worker] AI verdict compiled successfully', {
          ...ctx,
          verdictId: verdict._id.toString(),
          status: verdict.status,
          merchantSplit: verdict.merchantSplitPercent,
          customerSplit: verdict.customerSplitPercent,
        });

        // 4. Notify both merchant and customer
        const merchant = await Merchant.findById(invoice.merchantId);
        if (merchant) {
          await Promise.all([
            enqueueNotification({
              type: 'payment-confirmed', // generic user alert
              merchantUserId: merchant.userId.toString(),
              invoiceId,
              amountPaise: invoice.amountPaise,
              shopName: merchant.shopName,
            }),
            invoice.customerId
              ? enqueueNotification({
                  type: 'payment-confirmed',
                  customerUserId: invoice.customerId.toString(),
                  invoiceId,
                  amountPaise: invoice.amountPaise,
                  shopName: merchant.shopName,
                })
              : Promise.resolve(),
          ]);
        }
      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : 'AI arbitration error';
        logger.error('[dispute-worker] Dispute AI pipeline failed', { ...ctx, error: msg });
        throw err;
      }
    },
    {
      connection: bullMqRedis as any,
      concurrency: 2,
    }
  );

  return worker;
}
