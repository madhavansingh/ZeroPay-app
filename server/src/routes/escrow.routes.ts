/**
 * escrow.routes.ts
 *
 * REST API routes for the ZeroPay programmable escrow protocol.
 *
 * Routes:
 * - POST   /escrow/:invoiceId/lock              — Build lock TX (customer signs off-chain)
 * - POST   /escrow/:invoiceId/lock/submit       — Record confirmed lock TX hash
 * - POST   /escrow/:invoiceId/release           — Build milestone release TX
 * - POST   /escrow/:invoiceId/release/submit    — Record confirmed release TX hash
 * - POST   /escrow/:invoiceId/dispute           — Build dispute TX
 * - POST   /escrow/:invoiceId/dispute/submit    — Record dispute TX hash
 * - POST   /escrow/:invoiceId/resolve           — Admin builds resolution TX
 * - POST   /escrow/:invoiceId/resolve/submit    — Record resolution TX
 * - GET    /escrow/:invoiceId/status            — Get escrow state
 */

import { Router, Request, Response, NextFunction } from 'express';
import { requireAuth } from '../middleware/auth';
import { disputeRateLimit } from '../middleware/rateLimit';
import { riskMiddleware } from '../middleware/risk.middleware';
import { Invoice, isValidTransition, EscrowState } from '../models/Invoice';
import { Transaction } from '../models/Transaction';
import { domainEventBus, DomainEvents } from '../events/eventBus';
import {
  buildLockTx,
  buildReleaseMilestoneTx,
  buildRaiseDisputeTx,
  buildAdminResolveTx,
} from '../services/escrow.service';
import { updateMerchantReputation } from '../services/reputation.service';
import { logger } from '../config/logger';
import { enqueueNotification, enqueueTxConfirmation } from '../queues/queue.definitions';
import { Merchant } from '../models/Merchant';
import { injectChatMessage, mirrorEscrowToFirebase } from '../services/invoice.service';

import { chainAdapterRegistry } from '../adapters/chain';

const router = Router();

// ─── Inline validation helpers ────────────────────────────────────────────────

const INVOICE_ID_RE = /^INV-/;
const CARDANO_ADDR_RE = /^addr(_test)?1[a-z0-9]+$/;
const EVM_ADDR_RE = /^0x[a-fA-F0-9]{40}$/;
const CARDANO_TX_HASH_RE = /^[a-f0-9]{64}$/;
const EVM_TX_HASH_RE = /^0x[a-fA-F0-9]{64}$/;

function validateInvoiceId(id: unknown): id is string {
  return typeof id === 'string' && INVOICE_ID_RE.test(id);
}

function validateAddr(addr: unknown, network: 'cardano' | 'base' = 'cardano'): addr is string {
  if (typeof addr !== 'string') return false;
  if (network === 'base') {
    return EVM_ADDR_RE.test(addr);
  }
  return CARDANO_ADDR_RE.test(addr);
}

function validateTxHash(hash: unknown, network: 'cardano' | 'base' = 'cardano'): hash is string {
  if (typeof hash !== 'string') return false;
  if (network === 'base') {
    return EVM_TX_HASH_RE.test(hash);
  }
  return CARDANO_TX_HASH_RE.test(hash);
}

function badRequest(res: Response, message: string): void {
  res.status(400).json({ success: false, error: message });
}

// ─── GET /escrow/:invoiceId/status ────────────────────────────────────────────

router.get(
  '/:invoiceId/status',
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      if (!validateInvoiceId(req.params.invoiceId)) {
        badRequest(res, 'Invalid invoiceId format');
        return;
      }
      const invoice = await Invoice.findOne({ invoiceId: req.params.invoiceId });
      if (!invoice) {
        res.status(404).json({ success: false, error: 'Invoice not found' });
        return;
      }
      res.json({
        success: true,
        data: {
          invoiceId: invoice.invoiceId,
          status: invoice.status,
          escrowState: invoice.escrowState,
          milestoneIndex: invoice.milestoneIndex,
          totalMilestones: invoice.totalMilestones,
          isDisputed: invoice.isDisputed,
          milestones: invoice.milestones.map((m) => ({
            title: m.title,
            amountLovelace: m.amountLovelace,
            status: m.status,
            releasedAt: m.releasedAt,
          })),
        },
      });
    } catch (err) {
      next(err);
    }
  }
);

// ─── POST /escrow/:invoiceId/lock ─────────────────────────────────────────────

router.post(
  '/:invoiceId/lock',
  riskMiddleware,
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { customerAddress } = req.body as Record<string, unknown>;
      if (!validateInvoiceId(req.params.invoiceId)) { badRequest(res, 'Invalid invoiceId'); return; }

      const invoice = await Invoice.findOne({ invoiceId: req.params.invoiceId });
      if (!invoice) { res.status(404).json({ success: false, error: 'Invoice not found' }); return; }
      const network = invoice.network ?? 'cardano';

      if (!validateAddr(customerAddress, network)) { badRequest(res, 'Invalid customerAddress'); return; }

      const adapter = chainAdapterRegistry.getAdapter(network);
      const result = await adapter.buildLockTx(req.params.invoiceId, invoice.amountLovelace, customerAddress);
      res.json({ success: true, data: result });
    } catch (err) {
      logger.error('[escrow/lock] Build failed', {
        invoiceId: req.params.invoiceId,
        detail: err instanceof Error ? err.message : String(err),
      });
      next(err);
    }
  }
);

// ─── POST /escrow/:invoiceId/lock/submit ──────────────────────────────────────

router.post(
  '/:invoiceId/lock/submit',
  requireAuth,
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { txHash, customerAddress } = req.body as Record<string, unknown>;
      if (!validateInvoiceId(req.params.invoiceId)) { badRequest(res, 'Invalid invoiceId'); return; }

      const invoice = await Invoice.findOne({ invoiceId: req.params.invoiceId });
      if (!invoice) { res.status(404).json({ success: false, error: 'Invoice not found' }); return; }
      const network = invoice.network ?? 'cardano';

      if (!validateTxHash(txHash, network)) { badRequest(res, 'Invalid txHash'); return; }
      if (!validateAddr(customerAddress, network)) { badRequest(res, 'Invalid customerAddress'); return; }

      if (!isValidTransition(invoice.escrowState as EscrowState, 'Locked')) {
        res.status(409).json({ success: false, error: `Invalid escrow state transition from "${invoice.escrowState}" to "Locked"` });
        return;
      }

      // Check for duplicate txHash
      const existingTx = await Transaction.findOne({ txHash });
      if (existingTx) {
        res.status(409).json({ success: false, error: 'Transaction already submitted' });
        return;
      }

      await Invoice.findByIdAndUpdate(invoice._id, {
        $set: {
          escrowState: 'Locked',
          escrowLockTxHash: txHash,
          escrowCustomerAddress: customerAddress,
          status: 'submitted',
          txHash,
          submittedAt: new Date(),
        },
      });

      // Mirror detailed escrow state to Firebase
      await mirrorEscrowToFirebase(invoice.invoiceId, 'Locked', {
        milestoneIndex: 0,
        totalMilestones: invoice.totalMilestones,
        isDisputed: false,
        milestones: invoice.milestones.map((m) => ({
          title: m.title,
          amountLovelace: m.amountLovelace,
          status: m.status,
          releasedAt: m.releasedAt,
        })),
        escrowLockTxHash: txHash,
        escrowCustomerAddress: customerAddress,
      });

      // Create transaction record
      await Transaction.create({
        txHash,
        invoiceId: invoice._id,
        invoiceStringId: invoice.invoiceId,
        merchantId: invoice.merchantId,
        amountLovelaceExpected: invoice.amountLovelace,
        status: 'submitted',
      });

      logger.info('[escrow/lock/submit] Lock TX recorded and confirmation enqueued', { invoiceId: req.params.invoiceId, txHash });

      // Inject submitted message into chat room
      if (invoice.chatRoomId) {
        await injectChatMessage(invoice.chatRoomId, 'payment-submitted', {
          invoiceId: invoice.invoiceId,
          txHash,
          amountPaise: invoice.amountPaise,
          amountLovelace: invoice.amountLovelace,
          submittedAt: new Date().toISOString(),
        });
      }

      // Enqueue confirmation polling
      await enqueueTxConfirmation({
        invoiceId: invoice.invoiceId,
        txHash,
        merchantId: invoice.merchantId.toString(),
        customerId: invoice.customerId?.toString(),
        amountLovelace: invoice.amountLovelace,
        paymentAddress: invoice.paymentAddress,
      });

      const merchant = await Merchant.findById(invoice.merchantId);
      if (merchant?.userId) {
        await enqueueNotification({
          type: 'payment-incoming',
          merchantUserId: merchant.userId.toString(),
          invoiceId: invoice.invoiceId,
          amountPaise: invoice.amountPaise,
          shopName: merchant.shopName,
        });
      }

      // Publish EscrowLocked domain event
      domainEventBus.publish(DomainEvents.EscrowLocked, {
        invoiceId: invoice.invoiceId,
        txHash,
        amountLovelace: invoice.amountLovelace,
        customerAddress,
        actorId: req.user?.id || 'system',
        requestId: res.locals.requestId,
      });

      res.json({ success: true, data: { invoiceId: invoice.invoiceId, txHash, escrowState: 'Locked' } });
    } catch (err) {
      next(err);
    }
  }
);

// ─── POST /escrow/:invoiceId/release ──────────────────────────────────────────

router.post(
  '/:invoiceId/release',
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { customerAddress, scriptUtxoTxHash, scriptUtxoIndex, payoutLovelace } =
        req.body as Record<string, unknown>;

      if (!validateInvoiceId(req.params.invoiceId)) { badRequest(res, 'Invalid invoiceId'); return; }

      const invoice = await Invoice.findOne({ invoiceId: req.params.invoiceId });
      if (!invoice) { res.status(404).json({ success: false, error: 'Invoice not found' }); return; }
      const network = invoice.network ?? 'cardano';

      if (!validateAddr(customerAddress, network)) { badRequest(res, 'Invalid customerAddress'); return; }

      if (network === 'base') {
        const adapter = chainAdapterRegistry.getAdapter(network);
        const result = await adapter.buildReleaseTx(
          req.params.invoiceId,
          invoice.milestoneIndex,
          customerAddress
        );
        res.json({ success: true, data: result });
        return;
      }

      if (scriptUtxoTxHash !== undefined && !validateTxHash(scriptUtxoTxHash, network)) { badRequest(res, 'Invalid scriptUtxoTxHash'); return; }
      if (scriptUtxoIndex !== undefined && (typeof scriptUtxoIndex !== 'number' || scriptUtxoIndex < 0)) { badRequest(res, 'Invalid scriptUtxoIndex'); return; }
      if (payoutLovelace !== undefined && (typeof payoutLovelace !== 'number' || payoutLovelace < 1000000)) { badRequest(res, 'payoutLovelace must be >= 1000000'); return; }

      const result = await buildReleaseMilestoneTx(
        req.params.invoiceId,
        customerAddress as string,
        scriptUtxoTxHash as string | undefined,
        scriptUtxoIndex as number | undefined,
        payoutLovelace as number | undefined
      );
      res.json({ success: true, data: result });
    } catch (err) {
      logger.error('[escrow/release] Build failed', {
        invoiceId: req.params.invoiceId,
        detail: err instanceof Error ? err.message : String(err),
      });
      next(err);
    }
  }
);

router.post(
  '/:invoiceId/release/submit',
  requireAuth,
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { txHash, payoutLovelace } = req.body as Record<string, unknown>;
      if (!validateInvoiceId(req.params.invoiceId)) { badRequest(res, 'Invalid invoiceId'); return; }

      const invoice = await Invoice.findOne({ invoiceId: req.params.invoiceId });
      if (!invoice) { res.status(404).json({ success: false, error: 'Invoice not found' }); return; }
      const network = invoice.network ?? 'cardano';

      if (!validateTxHash(txHash, network)) { badRequest(res, 'Invalid txHash'); return; }
      if (network === 'cardano' && (typeof payoutLovelace !== 'number' || payoutLovelace < 1000000)) {
        badRequest(res, 'payoutLovelace must be >= 1000000');
        return;
      }
      const currentIndex = invoice.milestoneIndex;
      const totalMilestones = invoice.totalMilestones || 1;
      const isFinal = currentIndex + 1 >= totalMilestones;
      const nextEscrowState = isFinal ? 'Released' : 'PartiallyReleased';

      if (!isValidTransition(invoice.escrowState as EscrowState, nextEscrowState)) {
        res.status(409).json({ success: false, error: `Invalid escrow state transition from "${invoice.escrowState}" to "${nextEscrowState}"` });
        return;
      }

      const milestones = [...invoice.milestones];
      if (!milestones[currentIndex] || milestones[currentIndex].status !== 'pending') {
        res.status(409).json({ success: false, error: `Milestone at index ${currentIndex} is not in pending status` });
        return;
      }

      milestones[currentIndex].status = 'released';
      milestones[currentIndex].releasedAt = new Date();

      const nextStatus = isFinal ? 'confirmed' : invoice.status;

      await Invoice.findByIdAndUpdate(invoice._id, {
        $set: {
          escrowState: nextEscrowState,
          milestoneIndex: currentIndex + 1,
          milestones,
          txHash: isFinal ? txHash : invoice.txHash,
          ...(isFinal ? { confirmedAt: new Date() } : {}),
          status: nextStatus,
        },
      });

      // Mirror detailed escrow state to Firebase
      await mirrorEscrowToFirebase(invoice.invoiceId, nextEscrowState, {
        milestoneIndex: currentIndex + 1,
        milestones: milestones.map((m) => ({
          title: m.title,
          amountLovelace: m.amountLovelace,
          status: m.status,
          releasedAt: m.releasedAt,
        })),
        isDisputed: invoice.isDisputed,
      });

      logger.info('[escrow/release/submit] Milestone released', {
        invoiceId: req.params.invoiceId, milestoneIndex: currentIndex, isFinal, txHash,
      });

      // Publish MilestoneReleased domain event
      domainEventBus.publish(DomainEvents.MilestoneReleased, {
        invoiceId: invoice.invoiceId,
        txHash,
        milestoneIndex: currentIndex,
        payoutLovelace,
        isFinal,
        customerAddress: invoice.escrowCustomerAddress || '',
        actorId: req.user?.id || 'system',
        requestId: res.locals.requestId,
      });

      res.json({
        success: true,
        data: { invoiceId: req.params.invoiceId, txHash, milestoneIndex: currentIndex + 1, escrowState: nextEscrowState, isFinal },
      });
    } catch (err) {
      next(err);
    }
  }
);

// ─── POST /escrow/:invoiceId/dispute ──────────────────────────────────────────

router.post(
  '/:invoiceId/dispute',
  requireAuth,
  disputeRateLimit,
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { signerAddress, scriptUtxoTxHash, scriptUtxoIndex } = req.body as Record<string, unknown>;
      if (!validateInvoiceId(req.params.invoiceId)) { badRequest(res, 'Invalid invoiceId'); return; }

      const invoice = await Invoice.findOne({ invoiceId: req.params.invoiceId });
      if (!invoice) { res.status(404).json({ success: false, error: 'Invoice not found' }); return; }
      const network = invoice.network ?? 'cardano';

      if (!validateAddr(signerAddress, network)) { badRequest(res, 'Invalid signerAddress'); return; }

      if (network === 'base') {
        res.json({ success: true, data: { message: 'Base dispute initiated off-chain' } });
        return;
      }

      if (scriptUtxoTxHash !== undefined && !validateTxHash(scriptUtxoTxHash, network)) { badRequest(res, 'Invalid scriptUtxoTxHash'); return; }
      if (scriptUtxoIndex !== undefined && (typeof scriptUtxoIndex !== 'number' || scriptUtxoIndex < 0)) { badRequest(res, 'Invalid scriptUtxoIndex'); return; }

      const result = await buildRaiseDisputeTx(
        req.params.invoiceId,
        signerAddress as string,
        scriptUtxoTxHash as string | undefined,
        scriptUtxoIndex as number | undefined
      );
      res.json({ success: true, data: result });
    } catch (err) {
      logger.error('[escrow/dispute] Build failed', {
        invoiceId: req.params.invoiceId,
        detail: err instanceof Error ? err.message : String(err),
      });
      next(err);
    }
  }
);

// ─── POST /escrow/:invoiceId/dispute/submit ───────────────────────────────────

router.post(
  '/:invoiceId/dispute/submit',
  requireAuth,
  disputeRateLimit,
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { txHash } = req.body as Record<string, unknown>;
      if (!validateInvoiceId(req.params.invoiceId)) { badRequest(res, 'Invalid invoiceId'); return; }

      const invoice = await Invoice.findOne({ invoiceId: req.params.invoiceId });
      if (!invoice) { res.status(404).json({ success: false, error: 'Invoice not found' }); return; }
      const network = invoice.network ?? 'cardano';

      if (txHash !== undefined && !validateTxHash(txHash, network)) { badRequest(res, 'Invalid txHash'); return; }

      if (!isValidTransition(invoice.escrowState as EscrowState, 'Disputed')) {
        res.status(409).json({ success: false, error: `Invalid escrow state transition from "${invoice.escrowState}" to "Disputed"` });
        return;
      }

      await Invoice.findByIdAndUpdate(invoice._id, {
        $set: { escrowState: 'Disputed', isDisputed: true, disputeTxHash: txHash },
      });

      // Mirror detailed escrow state to Firebase
      await mirrorEscrowToFirebase(invoice.invoiceId, 'Disputed', {
        isDisputed: true,
        disputeTxHash: txHash,
      });

      logger.info('[escrow/dispute/submit] Dispute recorded', { invoiceId: req.params.invoiceId, txHash });

      // Publish DisputeRaised domain event
      domainEventBus.publish(DomainEvents.DisputeRaised, {
        invoiceId: invoice.invoiceId,
        txHash,
        signerAddress: invoice.escrowCustomerAddress || '',
        actorId: req.user?.id || 'system',
        requestId: res.locals.requestId,
      });

      res.json({ success: true, data: { invoiceId: req.params.invoiceId, txHash, escrowState: 'Disputed' } });
    } catch (err) {
      next(err);
    }
  }
);

// ─── POST /escrow/:invoiceId/resolve ──────────────────────────────────────────

router.post(
  '/:invoiceId/resolve',
  requireAuth,
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { adminAddress, customerAddress, scriptUtxoTxHash, scriptUtxoIndex, merchantPayoutLovelace, customerPayoutLovelace } =
        req.body as Record<string, unknown>;

      if (!validateInvoiceId(req.params.invoiceId)) { badRequest(res, 'Invalid invoiceId'); return; }

      const invoice = await Invoice.findOne({ invoiceId: req.params.invoiceId });
      if (!invoice) { res.status(404).json({ success: false, error: 'Invoice not found' }); return; }
      const network = invoice.network ?? 'cardano';

      if (!validateAddr(adminAddress, network)) { badRequest(res, 'Invalid adminAddress'); return; }
      if (!validateAddr(customerAddress, network)) { badRequest(res, 'Invalid customerAddress'); return; }

      if (network === 'base') {
        const adapter = chainAdapterRegistry.getAdapter(network);
        const merchantPayout = typeof merchantPayoutLovelace === 'number' ? merchantPayoutLovelace : invoice.amountLovelace;
        const customerPayout = typeof customerPayoutLovelace === 'number' ? customerPayoutLovelace : 0;
        const result = await adapter.buildResolveTx(
          req.params.invoiceId,
          merchantPayout,
          customerPayout
        );
        res.json({ success: true, data: result });
        return;
      }

      if (scriptUtxoTxHash !== undefined && !validateTxHash(scriptUtxoTxHash, network)) { badRequest(res, 'Invalid scriptUtxoTxHash'); return; }
      if (scriptUtxoIndex !== undefined && (typeof scriptUtxoIndex !== 'number' || scriptUtxoIndex < 0)) { badRequest(res, 'Invalid scriptUtxoIndex'); return; }
      if (merchantPayoutLovelace !== undefined && (typeof merchantPayoutLovelace !== 'number' || merchantPayoutLovelace < 0)) { badRequest(res, 'Invalid merchantPayoutLovelace'); return; }
      if (customerPayoutLovelace !== undefined && (typeof customerPayoutLovelace !== 'number' || customerPayoutLovelace < 0)) { badRequest(res, 'Invalid customerPayoutLovelace'); return; }

      const result = await buildAdminResolveTx(
        req.params.invoiceId,
        adminAddress as string,
        scriptUtxoTxHash as string | undefined,
        scriptUtxoIndex as number | undefined,
        merchantPayoutLovelace as number | undefined,
        customerPayoutLovelace as number | undefined,
        customerAddress as string
      );
      res.json({ success: true, data: result });
    } catch (err) {
      logger.error('[escrow/resolve] Build failed', {
        invoiceId: req.params.invoiceId,
        detail: err instanceof Error ? err.message : String(err),
      });
      next(err);
    }
  }
);

// ─── POST /escrow/:invoiceId/resolve/submit ───────────────────────────────────

router.post(
  '/:invoiceId/resolve/submit',
  requireAuth,
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { txHash } = req.body as Record<string, unknown>;
      if (!validateInvoiceId(req.params.invoiceId)) { badRequest(res, 'Invalid invoiceId'); return; }

      const invoice = await Invoice.findOne({ invoiceId: req.params.invoiceId });
      if (!invoice) { res.status(404).json({ success: false, error: 'Invoice not found' }); return; }
      const network = invoice.network ?? 'cardano';

      if (!validateTxHash(txHash, network)) { badRequest(res, 'Invalid txHash'); return; }

      if (!isValidTransition(invoice.escrowState as EscrowState, 'Resolved')) {
        res.status(409).json({ success: false, error: `Invalid escrow state transition from "${invoice.escrowState}" to "Resolved"` });
        return;
      }

      await Invoice.findByIdAndUpdate(invoice._id, {
        $set: {
          escrowState: 'Resolved',
          isDisputed: false,
          resolutionTxHash: txHash,
          status: 'settled',
          settledAt: new Date(),
        },
      });

      // Mirror detailed escrow state to Firebase
      await mirrorEscrowToFirebase(invoice.invoiceId, 'Resolved', {
        isDisputed: false,
        resolutionTxHash: txHash,
      });

      logger.info('[escrow/resolve/submit] Dispute resolved', { invoiceId: req.params.invoiceId, txHash });

      // Publish EscrowResolved domain event
      domainEventBus.publish(DomainEvents.EscrowResolved, {
        invoiceId: invoice.invoiceId,
        txHash,
        merchantPayoutLovelace: invoice.amountLovelace,
        customerPayoutLovelace: 0,
        actorId: req.user?.id || 'system',
        requestId: res.locals.requestId,
      });

      res.json({ success: true, data: { invoiceId: req.params.invoiceId, txHash, escrowState: 'Resolved' } });
    } catch (err) {
      next(err);
    }
  }
);

export default router;
