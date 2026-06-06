import { domainEventBus, DomainEvents } from './eventBus';
import { logProtocolActivity } from '../services/audit.service';
import { updateMerchantReputation } from '../services/reputation.service';
import { enqueueNotification, enqueueDigitalDelivery, enqueueDisputeResolution, NotificationJobData } from '../queues/queue.definitions';
import { Invoice } from '../models/Invoice';
import { Merchant } from '../models/Merchant';
import { Product } from '../models/Product';
import { triggerWebhooks } from '../services/webhook.service';
import { broadcastToRoom } from '../config/socketServer';
import { logger } from '../config/logger';
import { LedgerService } from '../services/ledger.service';
import { env } from '../config/env';

export function initSubscribers(): void {
  logger.info('[Subscribers] Initializing local domain event subscribers...');

  // ─── 1. EscrowLocked ───────────────────────────────────────────────────────
  domainEventBus.on(DomainEvents.EscrowLocked, async (payload) => {
    const { invoiceId, txHash, amountLovelace, customerAddress, actorId, requestId } = payload;
    
    // Log to immutable audit log
    await logProtocolActivity({
      eventType: DomainEvents.EscrowLocked,
      status: 'success',
      actorId: actorId || 'system',
      requestId,
      invoiceId,
      metadata: { txHash, amountLovelace, customerAddress },
      details: `Escrow funds locked. TxHash: ${txHash}. Amount: ${amountLovelace} Lovelace.`,
    });

    // Send Notification
    try {
      const invoice = await Invoice.findOne({ invoiceId });
      if (invoice) {
        // Record double-entry ledger lock
        if (invoice.customerId) {
          await LedgerService.recordLock({
            invoiceId,
            customerId: invoice.customerId.toString(),
            amountLovelace: invoice.amountLovelace,
            amountPaise: invoice.amountPaise,
          }).catch((err) => logger.error('[Ledger] Failed to record lock ledger entries', { error: err.message }));
        }

        const merchant = await Merchant.findById(invoice.merchantId);
        if (merchant) {
          await enqueueNotification({
            type: 'escrow-locked',
            merchantUserId: merchant.userId.toString(),
            customerUserId: invoice.customerId?.toString(),
            invoiceId,
            amountPaise: invoice.amountPaise,
            shopName: merchant.shopName,
          });

          // Trigger webhooks (fire-and-forget)
          triggerWebhooks(merchant._id.toString(), 'escrow.locked', {
            invoiceId,
            txHash,
            amountLovelace,
            customerAddress,
            status: invoice.status,
            escrowState: 'Locked',
          }).catch((err) => logger.warn('Failed to trigger escrow.locked webhook', { detail: err.message }));

          triggerWebhooks(merchant._id.toString(), 'invoice.paid', {
            invoiceId,
            txHash,
            amountLovelace,
            customerAddress,
            status: invoice.status,
          }).catch((err) => logger.warn('Failed to trigger invoice.paid webhook', { detail: err.message }));

          // Broadcast live updates via Socket.IO
          broadcastToRoom(`merchant:${merchant._id.toString()}`, 'payment:received', {
            invoiceId,
            amountPaise: invoice.amountPaise,
            status: invoice.status,
          });
          broadcastToRoom(`invoice:${invoiceId}`, 'escrow:stateChanged', {
            invoiceId,
            newState: 'Locked',
          });
        }
      }
    } catch (err: any) {
      logger.error('[Subscribers] Failed in EscrowLocked notification trigger:', { detail: err.message });
    }
  });

  // ─── 2. MilestoneReleased ──────────────────────────────────────────────────
  domainEventBus.on(DomainEvents.MilestoneReleased, async (payload) => {
    const { invoiceId, txHash, milestoneIndex, payoutLovelace, isFinal, customerAddress, actorId, requestId } = payload;

    // Log to immutable audit log
    await logProtocolActivity({
      eventType: DomainEvents.MilestoneReleased,
      status: 'success',
      actorId: actorId || 'system',
      requestId,
      invoiceId,
      metadata: { txHash, milestoneIndex, payoutLovelace, isFinal, customerAddress },
      details: `Milestone index ${milestoneIndex} released (${isFinal ? 'Final' : 'Partial'}). TxHash: ${txHash}. Payout: ${payoutLovelace} Lovelace.`,
    });

    try {
      const invoice = await Invoice.findOne({ invoiceId });
      if (invoice) {
        // Record double-entry ledger milestone release
        const proportion = payoutLovelace / invoice.amountLovelace;
        const milestonePaise = Math.round(invoice.amountPaise * proportion);

        const totalFeeLovelace = env.ESCROW_PLATFORM_FEE_LOVELACE;
        const totalFeePaise = Math.round(invoice.amountPaise * 0.02);

        const feeLovelace = Math.round(totalFeeLovelace * proportion);
        const feePaise = Math.round(totalFeePaise * proportion);

        await LedgerService.recordRelease({
          invoiceId,
          merchantId: invoice.merchantId.toString(),
          amountLovelace: payoutLovelace,
          amountPaise: milestonePaise,
          feeLovelace,
          feePaise,
        }).catch((err) => logger.error('[Ledger] Failed to record release ledger entries', { error: err.message }));

        // Trigger merchant reputation recalculation
        await updateMerchantReputation(invoice.merchantId.toString());

        // Send Notification
        const merchant = await Merchant.findById(invoice.merchantId);
        if (merchant) {
          await enqueueNotification({
            type: 'milestone-released',
            merchantUserId: merchant.userId.toString(),
            customerUserId: invoice.customerId?.toString(),
            invoiceId,
            amountPaise: invoice.amountPaise,
            shopName: merchant.shopName,
          });

          // Trigger webhooks (fire-and-forget)
          triggerWebhooks(merchant._id.toString(), 'milestone.released', {
            invoiceId,
            txHash,
            milestoneIndex,
            payoutLovelace,
            isFinal,
            customerAddress,
          }).catch((err) => logger.warn('Failed to trigger milestone.released webhook', { detail: err.message }));

          if (isFinal) {
            triggerWebhooks(merchant._id.toString(), 'escrow.released', {
              invoiceId,
              txHash,
              payoutLovelace,
              customerAddress,
            }).catch((err) => logger.warn('Failed to trigger escrow.released webhook', { detail: err.message }));
          }

          // Broadcast live updates via Socket.IO
          const newState = isFinal ? 'Released' : 'PartiallyReleased';
          broadcastToRoom(`invoice:${invoiceId}`, 'escrow:stateChanged', {
            invoiceId,
            newState,
            milestoneIndex,
          });
          broadcastToRoom(`merchant:${merchant._id.toString()}`, 'escrow:stateChanged', {
            invoiceId,
            newState,
            milestoneIndex,
          });
        }
        // Check if digital product delivery is needed
        if (isFinal && invoice.productId && invoice.customerId) {
          const product = await Product.findById(invoice.productId);
          if (product && (product.isDigital || product.category === 'digital') && product.ipfsHash) {
            await enqueueDigitalDelivery({
              invoiceId,
              productId: product._id.toString(),
              customerId: invoice.customerId.toString(),
              ipfsHash: product.ipfsHash,
            });
            logger.info('[Subscribers] Enqueued digital delivery for milestone release', { invoiceId, productId: product._id.toString() });
          }
        }
      }
    } catch (err: any) {
      logger.error('[Subscribers] Failed in MilestoneReleased updates:', { detail: err.message });
    }
  });

  // ─── 3. DisputeRaised ──────────────────────────────────────────────────────
  domainEventBus.on(DomainEvents.DisputeRaised, async (payload) => {
    const { invoiceId, txHash, signerAddress, actorId, requestId } = payload;

    // Log to immutable audit log
    await logProtocolActivity({
      eventType: DomainEvents.DisputeRaised,
      status: 'success',
      actorId: actorId || 'system',
      requestId,
      invoiceId,
      metadata: { txHash, signerAddress },
      details: `Dispute raised on escrow contract. TxHash: ${txHash}. Signer: ${signerAddress}`,
    });

    try {
      const invoice = await Invoice.findOne({ invoiceId });
      if (invoice) {
        const merchant = await Merchant.findById(invoice.merchantId);
        if (merchant) {
          await enqueueNotification({
            type: 'dispute-raised',
            merchantUserId: merchant.userId.toString(),
            customerUserId: invoice.customerId?.toString(),
            invoiceId,
            amountPaise: invoice.amountPaise,
            shopName: merchant.shopName,
          });

          // Trigger webhooks (fire-and-forget)
          triggerWebhooks(merchant._id.toString(), 'escrow.disputed', {
            invoiceId,
            txHash,
            signerAddress,
          }).catch((err) => logger.warn('Failed to trigger escrow.disputed webhook', { detail: err.message }));
          // Queue AI dispute resolution job
          await enqueueDisputeResolution({
            invoiceId,
            chatRoomId: invoice.chatRoomId,
            totalLovelace: invoice.amountLovelace,
            merchantId: invoice.merchantId.toString(),
            customerId: invoice.customerId ? invoice.customerId.toString() : '',
          });

          // Broadcast live updates via Socket.IO
          broadcastToRoom(`invoice:${invoiceId}`, 'escrow:stateChanged', {
            invoiceId,
            newState: 'Disputed',
          });
          broadcastToRoom(`merchant:${merchant._id.toString()}`, 'dispute:raised', {
            invoiceId,
          });
        }
      }
    } catch (err: any) {
      logger.error('[Subscribers] Failed in DisputeRaised notification trigger:', { detail: err.message });
    }
  });

  // ─── 4. RefundCompleted ────────────────────────────────────────────────────
  domainEventBus.on(DomainEvents.RefundCompleted, async (payload) => {
    const { invoiceId, txHash, payoutLovelace, customerAddress, actorId, requestId } = payload;

    // Log to immutable audit log
    await logProtocolActivity({
      eventType: DomainEvents.RefundCompleted,
      status: 'success',
      actorId: actorId || 'system',
      requestId,
      invoiceId,
      metadata: { txHash, payoutLovelace, customerAddress },
      details: `Escrow funds fully refunded to customer. TxHash: ${txHash}. Payout: ${payoutLovelace} Lovelace.`,
    });

    try {
      const invoice = await Invoice.findOne({ invoiceId });
      if (invoice) {
        // Record double-entry ledger refund
        if (invoice.customerId) {
          await LedgerService.recordRefund({
            invoiceId,
            customerId: invoice.customerId.toString(),
            amountLovelace: payoutLovelace,
            amountPaise: invoice.amountPaise,
          }).catch((err) => logger.error('[Ledger] Failed to record refund ledger entries', { error: err.message }));
        }

        const merchant = await Merchant.findById(invoice.merchantId);
        if (merchant) {
          await enqueueNotification({
            type: 'refund-completed',
            merchantUserId: merchant.userId.toString(),
            customerUserId: invoice.customerId?.toString(),
            invoiceId,
            amountPaise: invoice.amountPaise,
            shopName: merchant.shopName,
          });

          // Trigger webhooks (fire-and-forget)
          triggerWebhooks(merchant._id.toString(), 'invoice.expired', {
            invoiceId,
            txHash,
            payoutLovelace,
            customerAddress,
          }).catch((err) => logger.warn('Failed to trigger invoice.expired webhook', { detail: err.message }));

          // Broadcast live updates via Socket.IO
          broadcastToRoom(`invoice:${invoiceId}`, 'escrow:stateChanged', {
            invoiceId,
            newState: 'Refunded',
          });
          broadcastToRoom(`merchant:${merchant._id.toString()}`, 'escrow:stateChanged', {
            invoiceId,
            newState: 'Refunded',
          });
        }
      }
    } catch (err: any) {
      logger.error('[Subscribers] Failed in RefundCompleted notification trigger:', { detail: err.message });
    }
  });

  // ─── 5. EscrowResolved ─────────────────────────────────────────────────────
  domainEventBus.on(DomainEvents.EscrowResolved, async (payload) => {
    const { invoiceId, txHash, merchantPayoutLovelace, customerPayoutLovelace, actorId, requestId } = payload;

    // Log to immutable audit log
    await logProtocolActivity({
      eventType: DomainEvents.EscrowResolved,
      status: 'success',
      actorId: actorId || 'system',
      requestId,
      invoiceId,
      metadata: { txHash, merchantPayoutLovelace, customerPayoutLovelace },
      details: `Dispute resolved by Admin. TxHash: ${txHash}. Payouts: Merchant=${merchantPayoutLovelace} Lovelace, Customer=${customerPayoutLovelace} Lovelace.`,
    });

    try {
      const invoice = await Invoice.findOne({ invoiceId });
      if (invoice) {
        // Trigger merchant reputation recalculation
        await updateMerchantReputation(invoice.merchantId.toString());

        // Send Notification
        const merchant = await Merchant.findById(invoice.merchantId);
        if (merchant) {
          await enqueueNotification({
            type: 'payment-confirmed',
            merchantUserId: merchant.userId.toString(),
            customerUserId: invoice.customerId?.toString(),
            invoiceId,
            amountPaise: invoice.amountPaise,
            shopName: merchant.shopName,
          });

          // Trigger webhooks (fire-and-forget)
          triggerWebhooks(merchant._id.toString(), 'escrow.resolved', {
            invoiceId,
            txHash,
            merchantPayoutLovelace,
            customerPayoutLovelace,
          }).catch((err) => logger.warn('Failed to trigger escrow.resolved webhook', { detail: err.message }));

          // Broadcast live updates via Socket.IO
          broadcastToRoom(`invoice:${invoiceId}`, 'escrow:stateChanged', {
            invoiceId,
            newState: 'Resolved',
          });
          broadcastToRoom(`merchant:${merchant._id.toString()}`, 'escrow:stateChanged', {
            invoiceId,
            newState: 'Resolved',
          });
        }
        // Check if digital product delivery is needed
        if (invoice.productId && invoice.customerId) {
          const product = await Product.findById(invoice.productId);
          if (product && (product.isDigital || product.category === 'digital') && product.ipfsHash) {
            await enqueueDigitalDelivery({
              invoiceId,
              productId: product._id.toString(),
              customerId: invoice.customerId.toString(),
              ipfsHash: product.ipfsHash,
            });
            logger.info('[Subscribers] Enqueued digital delivery for escrow resolution', { invoiceId, productId: product._id.toString() });
          }
        }
      }
    } catch (err: any) {
      logger.error('[Subscribers] Failed in EscrowResolved updates:', { detail: err.message });
    }
  });

  // ─── 6. NotificationRequested ──────────────────────────────────────────────
  domainEventBus.on(DomainEvents.NotificationRequested, async (data: NotificationJobData) => {
    try {
      await enqueueNotification(data);
    } catch (err: any) {
      logger.error('[Subscribers] Failed to enqueue requested notification:', { detail: err.message });
    }
  });
}
