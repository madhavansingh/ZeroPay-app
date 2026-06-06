import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { requireAuth, requireMerchant, requireCustomer } from '../middleware/auth';
import { validate } from '../middleware/validate';
import { Merchant } from '../models/Merchant';
import { Product } from '../models/Product';
import { createInvoice } from '../services/invoice.service';
import { buildLockTx } from '../services/escrow.service';
import { getAdaInrRate } from '../services/price.service';
import { logger } from '../config/logger';

const router = Router();

const createProductSchema = z.object({
  title: z.string().min(3).max(80).trim(),
  description: z.string().min(10).max(1000).trim(),
  priceLovelace: z.number().int().min(1_000_000, 'Minimum 1 ADA'),
  priceINR: z.number().min(0).optional(),
  category: z.enum(['digital', 'physical', 'service']),
  isDigital: z.boolean().default(false),
  ipfsHash: z.string().trim().optional(),
  inventory: z.number().int().min(0).optional(),
  images: z.array(z.string().trim()).max(5).default([]),
  tags: z.array(z.string().trim()).max(10).default([]),
});

const updateProductSchema = createProductSchema.partial();

const buyProductSchema = z.object({
  customerAddress: z.string().regex(/^addr(_test)?1[a-z0-9]+$/, 'Invalid Cardano wallet address'),
});

// ── GET /api/v1/catalog/products/:id ─────────────────────────────────────────
router.get('/products/:id', async (req: Request, res: Response) => {
  try {
    const product = await Product.findOne({ _id: req.params.id, isActive: true });
    if (!product) {
      res.status(404).json({ success: false, error: 'Product not found' });
      return;
    }

    res.json({ success: true, data: product });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : 'Failed to fetch product';
    res.status(500).json({ success: false, error: msg });
  }
});

// ── POST /api/v1/catalog/products ────────────────────────────────────────────
router.post('/products', requireAuth, requireMerchant, validate(createProductSchema), async (req: Request, res: Response) => {
  try {
    const merchant = await Merchant.findOne({ userId: req.user._id });
    if (!merchant) {
      res.status(404).json({ success: false, error: 'Merchant profile not found' });
      return;
    }

    // Generate product UUID/nanoid for unique productId string
    const { nanoid } = await import('nanoid');
    const productId = `PROD-${nanoid(12)}`;

    const product = await Product.create({
      merchantId: merchant._id,
      productId,
      title: req.body.title,
      description: req.body.description,
      priceLovelace: req.body.priceLovelace,
      priceINR: req.body.priceINR,
      category: req.body.category,
      isDigital: req.body.category === 'digital' || req.body.isDigital,
      ipfsHash: req.body.ipfsHash,
      inventory: req.body.inventory,
      images: req.body.images,
      tags: req.body.tags,
      isActive: true,
      totalSold: 0,
    });

    logger.info('Product created', { productId: product.productId, merchantId: merchant.merchantId });

    res.status(201).json({ success: true, data: product });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : 'Failed to create product';
    res.status(500).json({ success: false, error: msg });
  }
});

// ── PUT /api/v1/catalog/products/:id ─────────────────────────────────────────
router.put('/products/:id', requireAuth, requireMerchant, validate(updateProductSchema), async (req: Request, res: Response) => {
  try {
    const merchant = await Merchant.findOne({ userId: req.user._id });
    if (!merchant) {
      res.status(404).json({ success: false, error: 'Merchant profile not found' });
      return;
    }

    const product = await Product.findOne({ _id: req.params.id, merchantId: merchant._id, isActive: true });
    if (!product) {
      res.status(404).json({ success: false, error: 'Product not found or not owned by you' });
      return;
    }

    const updateFields: any = {};
    if (req.body.title !== undefined) updateFields.title = req.body.title;
    if (req.body.description !== undefined) updateFields.description = req.body.description;
    if (req.body.priceLovelace !== undefined) updateFields.priceLovelace = req.body.priceLovelace;
    if (req.body.priceINR !== undefined) updateFields.priceINR = req.body.priceINR;
    if (req.body.category !== undefined) {
      updateFields.category = req.body.category;
      if (req.body.category === 'digital') {
        updateFields.isDigital = true;
      }
    }
    if (req.body.isDigital !== undefined) updateFields.isDigital = req.body.isDigital;
    if (req.body.ipfsHash !== undefined) updateFields.ipfsHash = req.body.ipfsHash;
    if (req.body.inventory !== undefined) updateFields.inventory = req.body.inventory;
    if (req.body.images !== undefined) updateFields.images = req.body.images;
    if (req.body.tags !== undefined) updateFields.tags = req.body.tags;

    const updated = await Product.findByIdAndUpdate(
      product._id,
      { $set: updateFields },
      { new: true }
    );

    res.json({ success: true, data: updated });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : 'Failed to update product';
    res.status(500).json({ success: false, error: msg });
  }
});

// ── DELETE /api/v1/catalog/products/:id ──────────────────────────────────────
router.delete('/products/:id', requireAuth, requireMerchant, async (req: Request, res: Response) => {
  try {
    const merchant = await Merchant.findOne({ userId: req.user._id });
    if (!merchant) {
      res.status(404).json({ success: false, error: 'Merchant profile not found' });
      return;
    }

    const product = await Product.findOne({ _id: req.params.id, merchantId: merchant._id, isActive: true });
    if (!product) {
      res.status(404).json({ success: false, error: 'Product not found or not owned by you' });
      return;
    }

    product.isActive = false;
    await product.save();

    logger.info('Product soft-deleted', { productId: product.productId, merchantId: merchant.merchantId });

    res.json({ success: true, message: 'Product successfully deleted' });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : 'Failed to delete product';
    res.status(500).json({ success: false, error: msg });
  }
});

// ── POST /api/v1/catalog/products/:id/buy ────────────────────────────────────
router.post('/products/:id/buy', requireAuth, requireCustomer, validate(buyProductSchema), async (req: Request, res: Response) => {
  try {
    const product = await Product.findOne({ _id: req.params.id, isActive: true });
    if (!product) {
      res.status(404).json({ success: false, error: 'Product not found' });
      return;
    }

    if (product.inventory !== undefined && product.inventory !== null && product.inventory <= 0) {
      res.status(400).json({ success: false, error: 'Product is out of stock' });
      return;
    }

    const merchant = await Merchant.findById(product.merchantId);
    if (!merchant || !merchant.isActive) {
      res.status(400).json({ success: false, error: 'Merchant profile is inactive or not found' });
      return;
    }

    // Convert priceLovelace to INR paise using exchange rate
    const priceData = await getAdaInrRate();
    const amountPaise = Math.round((product.priceLovelace / 1_000_000) * priceData.rate * 100);

    // Create a new Invoice/escrow contract
    const invoice = await createInvoice({
      merchantMongoId: merchant._id.toString(),
      amountPaise,
      description: `Purchase: ${product.title}`,
      customerId: req.user._id.toString(),
      productId: product._id.toString(),
    });

    // Build Cardano locking transaction
    const lockTx = await buildLockTx(invoice.invoiceId, req.body.customerAddress);

    // Track storefront conversions if storefront is active
    if (merchant.slug) {
      await Merchant.findByIdAndUpdate(merchant._id, { $inc: { totalStorefrontConversions: 1 } });
    }

    logger.info('Product one-click buy initiated', {
      productId: product.productId,
      invoiceId: invoice.invoiceId,
      customerId: req.user.firebaseUid,
    });

    res.status(201).json({
      success: true,
      data: {
        invoice: {
          invoiceId: invoice.invoiceId,
          amountPaise: invoice.amountPaise,
          amountLovelace: invoice.amountLovelace,
          adaInrRate: invoice.adaInrRate,
          paymentAddress: invoice.paymentAddress,
          status: invoice.status,
          expiresAt: invoice.expiresAt,
          description: invoice.description,
        },
        lockTx,
      },
    });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : 'Product purchase failed';
    logger.error('Product one-click buy failed', { productId: req.params.id, detail: msg });
    res.status(500).json({ success: false, error: msg });
  }
});

export default router;
