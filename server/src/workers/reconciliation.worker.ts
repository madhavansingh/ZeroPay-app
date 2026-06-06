import { Worker } from 'bullmq';
import { BlockfrostProvider, deserializeDatum } from '@meshsdk/core';
import { bullMqRedis } from '../config/redis';
import { env } from '../config/env';
import { logger } from '../config/logger';
import { Invoice, EscrowState } from '../models/Invoice';
import { ESCROW_SCRIPT_ADDRESS, findActiveEscrowUtxo } from '../services/escrow.service';
import { reconciliationQueue } from '../queues/queue.definitions';
import { mirrorEscrowToFirebase } from '../services/invoice.service';

export async function startReconciliationWorker(): Promise<Worker> {
  // Add repeatable job (every 5 minutes = 300,000ms)
  await reconciliationQueue.add(
    'reconcile-check',
    {},
    {
      repeat: { every: 300_000 },
      jobId: 'reconciliation-repeatable',
    }
  );

  const worker = new Worker(
    'escrow-reconciliation',
    async () => {
      logger.info('[reconciliation] Starting escrow reconciliation check...');
      try {
        const provider = new BlockfrostProvider(env.BLOCKFROST_PROJECT_ID);
        const utxos = await provider.fetchAddressUTxOs(ESCROW_SCRIPT_ADDRESS);
        
        if (!utxos || utxos.length === 0) {
          logger.debug('[reconciliation] No active UTxOs found at script address');
          return;
        }

        // Map of invoiceId -> active UTxO
        const onChainInvoices = new Map<string, {
          txHash: string;
          txIndex: number;
          milestoneIndex: number;
          totalMilestones: number;
          stateAlt: number;
        }>();

        for (const utxo of utxos) {
          const datumCbor = utxo.output.plutusData;
          if (!datumCbor) continue;
          try {
            const datum = deserializeDatum<any>(datumCbor);
            const hexInvoiceId = datum.fields[3];
            if (typeof hexInvoiceId === 'string') {
              const invoiceId = Buffer.from(hexInvoiceId, 'hex').toString('utf8');
              const milestoneIndex = Number(datum.fields[8]);
              const totalMilestones = Number(datum.fields[9]);
              const stateAlt = Number(datum.fields[10].alternative); // 0=Locked, 1=PartiallyReleased, 2=Disputed

              onChainInvoices.set(invoiceId, {
                txHash: utxo.input.txHash,
                txIndex: utxo.input.outputIndex,
                milestoneIndex,
                totalMilestones,
                stateAlt,
              });
            }
          } catch (e: any) {
            logger.warn('[reconciliation] Failed deserializing script datum', { txHash: utxo.input.txHash, error: e.message });
          }
        }

        // Fetch all active invoices in the database (escrowState is Locked, PartiallyReleased, or Disputed)
        const dbInvoices = await Invoice.find({
          escrowState: { $in: ['Locked', 'PartiallyReleased', 'Disputed'] }
        });

        for (const invoice of dbInvoices) {
          const onChain = onChainInvoices.get(invoice.invoiceId);
          if (!onChain) {
            // Invoice is marked active in DB, but the UTxO is spent/not present on-chain.
            // This means the escrow was completed (all milestones released) or fully resolved.
            logger.warn('[reconciliation] Active DB invoice has no active on-chain UTxO', {
              invoiceId: invoice.invoiceId,
              currentDbState: invoice.escrowState
            });
            // We should reconcile by setting the final terminal state (if all milestones were released, mark as Released)
            const allReleased = invoice.milestones.every(m => m.status === 'released');
            if (invoice.escrowState !== 'Released' && invoice.escrowState !== 'Resolved') {
              const finalState = allReleased ? 'Released' : 'Resolved'; // resolved if it was disputed and now gone
              logger.info(`[reconciliation] Transitioning invoice ${invoice.invoiceId} to terminal state "${finalState}"`, { invoiceId: invoice.invoiceId });
              
              invoice.escrowState = finalState;
              if (finalState === 'Released') {
                invoice.status = 'confirmed';
              }
              await invoice.save();
              await mirrorEscrowToFirebase(invoice.invoiceId, finalState, {
                milestoneIndex: invoice.milestoneIndex,
                milestones: invoice.milestones,
              });
            }
            continue;
          }

          // Convert on-chain state alt to DB state
          let expectedState: EscrowState = 'Locked';
          if (onChain.stateAlt === 1) expectedState = 'PartiallyReleased';
          if (onChain.stateAlt === 2) expectedState = 'Disputed';

          let hasChanges = false;

          // 1. Reconcile escrow state
          if (invoice.escrowState !== expectedState) {
            logger.info(`[reconciliation] State desync detected for ${invoice.invoiceId}: DB="${invoice.escrowState}", Chain="${expectedState}". Syncing to Chain.`, { invoiceId: invoice.invoiceId });
            invoice.escrowState = expectedState;
            if (expectedState === 'Disputed') {
              invoice.isDisputed = true;
            }
            hasChanges = true;
          }

          // 2. Reconcile milestone index
          if (invoice.milestoneIndex < onChain.milestoneIndex) {
            logger.info(`[reconciliation] Milestone index desync detected for ${invoice.invoiceId}: DB=${invoice.milestoneIndex}, Chain=${onChain.milestoneIndex}. Syncing to Chain.`, { invoiceId: invoice.invoiceId });
            
            // Update milestone statuses up to the on-chain index
            const updatedMilestones = [...invoice.milestones];
            for (let i = 0; i < onChain.milestoneIndex; i++) {
              if (updatedMilestones[i] && updatedMilestones[i].status !== 'released') {
                updatedMilestones[i].status = 'released';
                updatedMilestones[i].releasedAt = new Date();
              }
            }
            invoice.milestoneIndex = onChain.milestoneIndex;
            invoice.milestones = updatedMilestones;
            hasChanges = true;
          }

          if (hasChanges) {
            await invoice.save();
            await mirrorEscrowToFirebase(invoice.invoiceId, invoice.escrowState, {
              milestoneIndex: invoice.milestoneIndex,
              milestones: invoice.milestones.map((m) => ({
                title: m.title,
                amountLovelace: m.amountLovelace,
                status: m.status,
                releasedAt: m.releasedAt,
              })),
              isDisputed: invoice.isDisputed,
            });
          }
        }
      } catch (err: any) {
        logger.error('[reconciliation] Check failed with error', { error: err.message });
      }
    },
    {
      connection: bullMqRedis as any,
      concurrency: 1,
    }
  );

  worker.on('active', (job) => {
    logger.debug('[reconciliation] Job active', { jobId: job.id ?? undefined });
  });
  worker.on('completed', (job) => {
    logger.debug('[reconciliation] Job completed', { jobId: job.id ?? undefined });
  });
  worker.on('failed', (job, err) => {
    logger.error('[reconciliation] Job failed', { jobId: job?.id ?? undefined, detail: err.message });
  });

  return worker;
}
