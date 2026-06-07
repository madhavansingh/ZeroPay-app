import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { requireAuth, requireMerchant } from '../middleware/auth';
import { validate } from '../middleware/validate';
import { invoiceRateLimit } from '../middleware/rateLimit';
import { Merchant } from '../models/Merchant';
import { Invoice } from '../models/Invoice';
import { createInvoice, getInvoiceById } from '../services/invoice.service';

const router = Router();

const createSchema = z.object({
  amountPaise: z
    .number()
    .int('Amount must be an integer (paise)')
    .min(100, 'Minimum ₹1.00')
    .max(50_000_000, 'Maximum ₹5,00,000'),
  description: z.string().max(100).trim().optional(),
  chatRoomId: z.string().optional(),
  customerId: z.string().optional(),
  milestones: z
    .array(
      z.object({
        title: z.string().min(1, 'Milestone title is required').max(100),
        amountPaise: z.number().int().positive('Milestone amount must be positive'),
      })
    )
    .optional(),
  network: z.enum(['cardano', 'base']).optional(),
});

// POST /api/v1/invoices/create
router.post(
  '/create',
  requireAuth,
  requireMerchant,
  invoiceRateLimit,
  validate(createSchema),
  async (req: Request, res: Response): Promise<void> => {
    try {
      const { amountPaise, description, chatRoomId, customerId, milestones, network } =
        req.body as z.infer<typeof createSchema>;

      const merchant = await Merchant.findOne({ userId: req.user._id });
      if (!merchant) {
        res.status(400).json({ success: false, error: 'Merchant profile not found' });
        return;
      }

      const invoice = await createInvoice({
        merchantMongoId: merchant.id as string,
        amountPaise,
        description,
        chatRoomId,
        customerId,
        milestones,
        network,
      });

      res.status(201).json({
        success: true,
        data: {
          invoiceId: invoice.invoiceId,
          amountPaise: invoice.amountPaise,
          amountLovelace: invoice.amountLovelace,
          adaInrRate: invoice.adaInrRate,
          paymentAddress: invoice.paymentAddress,
          status: invoice.status,
          expiresAt: invoice.expiresAt,
          description: invoice.description,
          network: invoice.network,
        },
      });
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Invoice creation failed';
      res.status(400).json({ success: false, error: message });
    }
  }
);

// GET /api/v1/invoices/:invoiceId
router.get('/:invoiceId', requireAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const invoice = await getInvoiceById(req.params.invoiceId);
    if (!invoice) {
      res.status(404).json({ success: false, error: 'Invoice not found' });
      return;
    }

    const merchant = await Merchant.findById(invoice.merchantId);
    const isMerchant = merchant && merchant.userId?.toString() === req.user._id.toString();
    const isCustomer = invoice.customerId && invoice.customerId.toString() === req.user._id.toString();
    if (!isMerchant && !isCustomer) {
      res.status(403).json({ success: false, error: 'Access denied: You do not have permission to view this invoice.' });
      return;
    }

    res.json({
      success: true,
      data: {
        invoiceId: invoice.invoiceId,
        merchantStringId: invoice.merchantStringId,
        amountPaise: invoice.amountPaise,
        amountLovelace: invoice.amountLovelace,
        adaInrRate: invoice.adaInrRate,
        paymentAddress: invoice.paymentAddress,
        status: invoice.status,
        txHash: invoice.txHash,
        expiresAt: invoice.expiresAt,
        description: invoice.description,
        receiptCid: invoice.receiptCid,
        chatRoomId: invoice.chatRoomId,
        createdAt: invoice.createdAt,
        settledAt: invoice.settledAt,
        escrowState: invoice.escrowState,
        milestones: invoice.milestones,
        milestoneIndex: invoice.milestoneIndex,
        totalMilestones: invoice.totalMilestones,
        isDisputed: invoice.isDisputed,
        agreementHash: invoice.agreementHash,
        metadataHash: invoice.metadataHash,
        contractVersion: invoice.contractVersion,
        network: invoice.network,
      },
    });
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Failed to fetch invoice';
    res.status(500).json({ success: false, error: message });
  }
});

// GET /api/v1/invoices/merchant/list
router.get(
  '/merchant/list',
  requireAuth,
  requireMerchant,
  async (req: Request, res: Response): Promise<void> => {
    try {
      const merchant = await Merchant.findOne({ userId: req.user._id });
      if (!merchant) {
        res.status(404).json({ success: false, error: 'Merchant not found' });
        return;
      }

      const page = Math.max(1, parseInt(String(req.query.page ?? '1'), 10));
      const limit = Math.min(50, parseInt(String(req.query.limit ?? '20'), 10));
      const statusFilter = req.query.status as string | undefined;

      const filter: Record<string, unknown> = { merchantId: merchant._id };
      if (statusFilter) filter.status = statusFilter;

      const [invoices, total] = await Promise.all([
        Invoice.find(filter)
          .sort({ createdAt: -1 })
          .skip((page - 1) * limit)
          .limit(limit)
          .lean(),
        Invoice.countDocuments(filter),
      ]);

      res.json({
        success: true,
        data: {
          items: invoices.map((inv) => ({
            invoiceId: inv.invoiceId,
            amountPaise: inv.amountPaise,
            amountLovelace: inv.amountLovelace,
            status: inv.status,
            description: inv.description,
            createdAt: inv.createdAt,
            settledAt: inv.settledAt,
            txHash: inv.txHash,
            escrowState: inv.escrowState,
            isDisputed: inv.isDisputed,
            chatRoomId: inv.chatRoomId,
            paymentAddress: inv.paymentAddress,
            escrowCustomerAddress: inv.escrowCustomerAddress,
          })),
          total,
          page,
          limit,
          hasMore: page * limit < total,
        },
      });
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Failed to list invoices';
      res.status(500).json({ success: false, error: message });
    }
  }
);

// GET /api/v1/invoices/customer/list
router.get(
  '/customer/list',
  requireAuth,
  async (req: Request, res: Response): Promise<void> => {
    try {
      const page = Math.max(1, parseInt(String(req.query.page ?? '1'), 10));
      const limit = Math.min(50, parseInt(String(req.query.limit ?? '20'), 10));
      const statusFilter = req.query.status as string | undefined;

      const filter: Record<string, unknown> = { customerId: req.user._id };
      if (statusFilter) filter.status = statusFilter;

      const [invoices, total] = await Promise.all([
        Invoice.find(filter)
          .sort({ createdAt: -1 })
          .skip((page - 1) * limit)
          .limit(limit)
          .lean(),
        Invoice.countDocuments(filter),
      ]);

      res.json({
        success: true,
        data: {
          items: invoices.map((inv) => ({
            invoiceId: inv.invoiceId,
            amountPaise: inv.amountPaise,
            amountLovelace: inv.amountLovelace,
            status: inv.status,
            description: inv.description,
            createdAt: inv.createdAt,
            settledAt: inv.settledAt,
            txHash: inv.txHash,
            escrowState: inv.escrowState,
            isDisputed: inv.isDisputed,
            chatRoomId: inv.chatRoomId,
            paymentAddress: inv.paymentAddress,
            escrowCustomerAddress: inv.escrowCustomerAddress,
          })),
          total,
          page,
          limit,
          hasMore: page * limit < total,
        },
      });
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Failed to list customer invoices';
      res.status(500).json({ success: false, error: message });
    }
  }
);

export default router;
