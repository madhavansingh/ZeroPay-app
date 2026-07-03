import { nanoid } from 'nanoid';
import { Invoice, IInvoice } from '../models/Invoice';
import { Merchant } from '../models/Merchant';
import { getFirebaseDatabase } from '../config/firebase-admin';
import { getAdaInrRate, paiseToLovelace } from './price.service';
import { triggerWebhooks } from './webhook.service';
import { logger } from '../config/logger';
import type { InvoiceStatus } from '@zeropay/shared-types';


function generateInvoiceId(): string {
  const date = new Date().toISOString().slice(0, 10).replace(/-/g, '');
  const suffix = nanoid(6).toUpperCase().replace(/[^A-Z0-9]/g, 'X');
  return `INV-${date}-${suffix}`;
}

export interface CreateInvoiceInput {
  merchantMongoId: string;
  amountPaise: number;
  description?: string;
  customerId?: string;
  productId?: string;
  chatRoomId?: string;
  milestones?: Array<{ milestoneId?: string; title: string; description?: string; amountPaise: number }>;
  network?: 'cardano' | 'base';
  projectPlanId?: string;
  auditRequired?: boolean;
}

export async function createInvoice(input: CreateInvoiceInput): Promise<IInvoice> {
  // Fetch merchant (source of truth for address + expiry)
  const merchant = await Merchant.findById(input.merchantMongoId);
  if (!merchant) throw new Error('Merchant not found');
  if (!merchant.isActive) throw new Error('Merchant account is inactive');
  if (!merchant.paymentAddress) throw new Error('Merchant has no payment address configured');

  // Validate amount
  if (input.amountPaise < 100) throw new Error('Minimum invoice amount is ₹1.00');
  if (input.amountPaise > 50000000) throw new Error('Maximum invoice amount is ₹5,00,000');

  // Lock rate at creation time
  const priceData = await getAdaInrRate();
  const amountLovelace = paiseToLovelace(input.amountPaise, priceData.rate);

  if (amountLovelace < 1_000_000) {
    throw new Error('Amount too small — minimum 1 ADA required after conversion');
  }

  // Validate and parse milestones
  let parsedMilestones: Array<{ milestoneId?: string; title: string; description?: string; amountLovelace: number; status: 'pending' }> = [];
  if (input.milestones && input.milestones.length > 0) {
    const sumPaise = input.milestones.reduce((sum, m) => sum + m.amountPaise, 0);
    if (sumPaise !== input.amountPaise) {
      throw new Error(`Sum of milestones (₹${(sumPaise / 100).toFixed(2)}) must equal total amount (₹${(input.amountPaise / 100).toFixed(2)})`);
    }

    parsedMilestones = input.milestones.map((m) => {
      const milestoneLovelace = paiseToLovelace(m.amountPaise, priceData.rate);
      return {
        milestoneId: m.milestoneId,
        title: m.title,
        description: m.description,
        amountLovelace: milestoneLovelace,
        status: 'pending' as const,
      };
    });
  }

  const invoiceId = generateInvoiceId();
  const expiresAt = new Date(Date.now() + merchant.invoiceExpiry * 1000);

  const totalMilestones = parsedMilestones.length;
  const escrowState = totalMilestones > 0 ? 'Created' : 'None';

  const invoice = await Invoice.create({
    invoiceId,
    merchantId: merchant._id,
    merchantStringId: merchant.merchantId,
    customerId: input.customerId ?? undefined,
    productId: input.productId ?? undefined,
    chatRoomId: input.chatRoomId ?? undefined,
    projectPlanId: input.projectPlanId,
    description: input.description?.trim(),
    amountPaise: input.amountPaise,
    amountLovelace,
    adaInrRate: priceData.rate,
    paymentAddress: merchant.paymentAddress,
    status: 'pending',
    expiresAt,
    escrowState,
    milestones: parsedMilestones,
    totalMilestones,
    milestoneIndex: 0,
    isDisputed: false,
    network: input.network ?? 'cardano',
    auditRequired: input.auditRequired ?? false,
  });

  // Mirror status to Firebase RTDB for real-time frontend updates
  await mirrorStatusToFirebase(invoiceId, 'pending');
  if (totalMilestones > 0) {
    logger.info(`[ESCROW_CREATED] Escrow ID: ${invoice.invoiceId} | Wallet Address: ${invoice.paymentAddress} | Amount: ${invoice.amountLovelace} Lovelace | Network: ${invoice.network} | Transaction Hash: N/A`);
    await mirrorEscrowToFirebase(invoiceId, 'Created', {
      milestoneIndex: 0,
      totalMilestones,
      isDisputed: false,
      milestones: parsedMilestones,
    });
  }

  // Inject payment_request message to chat room if this is a chat payment
  if (input.chatRoomId) {
    await injectChatMessage(input.chatRoomId, 'payment-request', {
      invoiceId,
      merchantId: merchant.merchantId,
      shopName: merchant.shopName,
      amountPaise: input.amountPaise,
      amountLovelace,
      adaInrRate: priceData.rate,
      description: input.description ?? null,
      expiresAt: expiresAt.toISOString(),
    });
  }

  // Trigger invoice.created webhook (fire-and-forget)
  triggerWebhooks(merchant._id.toString(), 'invoice.created', {
    invoiceId: invoice.invoiceId,
    amountPaise: invoice.amountPaise,
    amountLovelace: invoice.amountLovelace,
    adaInrRate: invoice.adaInrRate,
    status: invoice.status,
    expiresAt: invoice.expiresAt,
  }).catch((err) => logger.warn('Failed to trigger invoice.created webhook', { detail: err.message }));

  return invoice;
}

export async function getInvoiceById(invoiceId: string): Promise<IInvoice | null> {
  return Invoice.findOne({ invoiceId });
}

export async function transitionInvoiceStatus(
  invoiceId: string,
  fromStatus: InvoiceStatus,
  toStatus: InvoiceStatus,
  updates: Partial<IInvoice> = {}
): Promise<IInvoice | null> {
  // Optimistic locking: only update if status matches expected
  const invoice = await Invoice.findOneAndUpdate(
    { invoiceId, status: fromStatus },
    {
      $set: {
        status: toStatus,
        ...updates,
        ...(toStatus === 'submitted' && { submittedAt: new Date() }),
        ...(toStatus === 'confirming' && { confirmingAt: new Date() }),
        ...(toStatus === 'confirmed' && { confirmedAt: new Date() }),
        ...(toStatus === 'settled' && { settledAt: new Date() }),
      },
    },
    { new: true }
  );

  if (invoice) {
    await mirrorStatusToFirebase(invoiceId, toStatus);
  }

  return invoice;
}

export async function expireStaleInvoices(): Promise<number> {
  const now = new Date();
  const result = await Invoice.updateMany(
    { status: 'pending', expiresAt: { $lte: now } },
    { $set: { status: 'expired' } }
  );

  // Mirror each expired invoice to Firebase
  if (result.modifiedCount > 0) {
    const expiredInvoices = await Invoice.find(
      { status: 'expired', expiresAt: { $lte: now } },
      { invoiceId: 1 }
    ).limit(100);

    await Promise.all(
      expiredInvoices.map((inv) => mirrorStatusToFirebase(inv.invoiceId, 'expired'))
    );
  }

  return result.modifiedCount;
}

// ─── Firebase helpers ─────────────────────────────────────────────────────────

export async function mirrorStatusToFirebase(
  invoiceId: string,
  status: InvoiceStatus
): Promise<void> {
  try {
    const db = getFirebaseDatabase();
    await db.ref(`/invoices/${invoiceId}`).set(status);
  } catch (err) {
    // Non-fatal: MongoDB is source of truth
    console.warn(`[invoice] Firebase mirror failed for ${invoiceId}:`, err);
  }
}

export async function mirrorEscrowToFirebase(
  invoiceId: string,
  escrowState: string,
  updates: {
    milestoneIndex?: number;
    totalMilestones?: number;
    isDisputed?: boolean;
    milestones?: any[];
    [key: string]: any;
  } = {}
): Promise<void> {
  try {
    const db = getFirebaseDatabase();
    await db.ref(`/escrow/${invoiceId}`).update({
      escrowState,
      updatedAt: Date.now(),
      ...updates,
    });
  } catch (err) {
    // Non-fatal
    console.warn(`[invoice] Firebase escrow mirror failed for ${invoiceId}:`, err);
  }
}


export async function injectChatMessage(
  chatRoomId: string,
  type: string,
  payload: Record<string, unknown>
): Promise<void> {
  try {
    const db = getFirebaseDatabase();
    const ref = db.ref(`/chats/${chatRoomId}/messages`).push();
    await ref.set({
      senderId: 'system',
      type,
      timestamp: Date.now(),
      payload,
    });

    // Update lastMessage preview
    let preview = 'New message';
    if (type === 'payment-request') {
      preview = '💳 Payment Request';
    } else if (type === 'payment-submitted') {
      preview = '⏳ Payment Submitted';
    } else if (type === 'receipt') {
      preview = '✅ Payment Confirmed';
    }

    await db.ref(`/chatrooms/${chatRoomId}/lastMessage`).set({
      preview,
      timestamp: Date.now(),
    });
  } catch (err) {
    console.warn(`[invoice] Chat injection failed for room ${chatRoomId}:`, err);
  }
}
