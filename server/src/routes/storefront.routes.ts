import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { requireAuth, requireMerchant, requireCustomer } from '../middleware/auth';
import { validate } from '../middleware/validate';
import { Merchant } from '../models/Merchant';
import { Product } from '../models/Product';
import { Review } from '../models/Review';
import { Invoice } from '../models/Invoice';
import { logger } from '../config/logger';

const router = Router();

const setupStorefrontSchema = z.object({
  slug: z.string().regex(/^[a-z0-9][a-z0-9-]{1,48}[a-z0-9]$/, 'Invalid slug format. Use lowercase alphanumeric and hyphens (3-50 chars).'),
  profileImageUrl: z.string().url().optional(),
  bannerImageUrl: z.string().url().optional(),
  location: z.object({
    city: z.string().max(100).optional(),
    state: z.string().max(100).optional(),
    country: z.string().max(100).optional(),
  }).optional(),
  socialLinks: z.object({
    instagram: z.string().optional(),
    twitter: z.string().optional(),
    website: z.string().optional(),
  }).optional(),
  isPublicStorefront: z.boolean().default(false),
  businessHours: z.string().max(500).optional(),
});

const updateStorefrontSchema = setupStorefrontSchema.partial();

const reviewSchema = z.object({
  invoiceId: z.string(),
  productId: z.string().optional(),
  rating: z.number().int().min(1).max(5),
  body: z.string().max(400).optional(),
});

// ── GET /api/v1/storefronts/search ───────────────────────────────────────────
router.get('/search', async (req: Request, res: Response) => {
  try {
    const { q, category, city } = req.query;

    const query: any = { isPublicStorefront: true, isActive: true };

    if (city && typeof city === 'string') {
      query['location.city'] = new RegExp(city, 'i');
    }

    if (category && typeof category === 'string') {
      query.category = category;
    }

    if (q && typeof q === 'string') {
      query.$text = { $search: q };
    }

    const merchants = await Merchant.find(query)
      .select('merchantId shopName slug category description reputationScore reliabilityTier verifiedMerchantBadge location profileImageUrl bannerImageUrl')
      .sort({ reputationScore: -1 })
      .limit(20);

    res.json({ success: true, data: merchants });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : 'Failed to search storefronts';
    res.status(500).json({ success: false, error: msg });
  }
});

// ── GET /api/v1/storefronts/featured ─────────────────────────────────────────
router.get('/featured', async (_req: Request, res: Response) => {
  try {
    const featured = await Merchant.find({ isPublicStorefront: true, isActive: true })
      .select('merchantId shopName slug category description reputationScore reliabilityTier verifiedMerchantBadge location profileImageUrl bannerImageUrl')
      .sort({ reputationScore: -1, totalStorefrontConversions: -1 })
      .limit(5);

    res.json({ success: true, data: featured });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : 'Failed to fetch featured storefronts';
    res.status(500).json({ success: false, error: msg });
  }
});

// ── GET /api/v1/storefronts/:slug ────────────────────────────────────────────
router.get('/:slug', async (req: Request, res: Response) => {
  try {
    const merchant = await Merchant.findOneAndUpdate(
      { slug: req.params.slug.toLowerCase(), isPublicStorefront: true, isActive: true },
      { $inc: { totalStorefrontViews: 1 } },
      { new: true }
    ).select('-userId -totalReceivedLovelace');

    if (!merchant) {
      res.status(404).json({ success: false, error: 'Storefront not found' });
      return;
    }

    res.json({ success: true, data: merchant });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : 'Failed to fetch storefront';
    res.status(500).json({ success: false, error: msg });
  }
});

// ── GET /api/v1/storefronts/:slug/catalog ────────────────────────────────────
router.get('/:slug/catalog', async (req: Request, res: Response) => {
  try {
    const merchant = await Merchant.findOne({ slug: req.params.slug.toLowerCase(), isPublicStorefront: true, isActive: true });
    if (!merchant) {
      res.status(404).json({ success: false, error: 'Storefront not found' });
      return;
    }

    const products = await Product.find({ merchantId: merchant._id, isActive: true })
      .sort({ createdAt: -1 });

    res.json({ success: true, data: products });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : 'Failed to fetch catalog';
    res.status(500).json({ success: false, error: msg });
  }
});

// ── POST /api/v1/storefronts/setup ───────────────────────────────────────────
router.post('/setup', requireAuth, requireMerchant, validate(setupStorefrontSchema), async (req: Request, res: Response) => {
  try {
    const merchant = await Merchant.findOne({ userId: req.user._id });
    if (!merchant) {
      res.status(404).json({ success: false, error: 'Merchant not found' });
      return;
    }

    const slugLower = req.body.slug.toLowerCase();
    const existing = await Merchant.findOne({ slug: slugLower, _id: { $ne: merchant._id } });
    if (existing) {
      res.status(400).json({ success: false, error: 'Storefront slug is already taken' });
      return;
    }

    const updated = await Merchant.findByIdAndUpdate(
      merchant._id,
      {
        $set: {
          slug: slugLower,
          profileImageUrl: req.body.profileImageUrl,
          bannerImageUrl: req.body.bannerImageUrl,
          location: req.body.location,
          socialLinks: req.body.socialLinks,
          isPublicStorefront: req.body.isPublicStorefront,
          businessHours: req.body.businessHours,
        },
      },
      { new: true }
    );

    logger.info('Storefront setup complete', { merchantId: merchant.merchantId, slug: slugLower });

    res.json({ success: true, data: updated });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : 'Storefront setup failed';
    res.status(500).json({ success: false, error: msg });
  }
});

// ── PUT /api/v1/storefronts/update ───────────────────────────────────────────
router.put('/update', requireAuth, requireMerchant, validate(updateStorefrontSchema), async (req: Request, res: Response) => {
  try {
    const merchant = await Merchant.findOne({ userId: req.user._id });
    if (!merchant) {
      res.status(404).json({ success: false, error: 'Merchant not found' });
      return;
    }

    const updateFields: any = {};
    if (req.body.slug !== undefined) {
      const slugLower = req.body.slug.toLowerCase();
      const existing = await Merchant.findOne({ slug: slugLower, _id: { $ne: merchant._id } });
      if (existing) {
        res.status(400).json({ success: false, error: 'Storefront slug is already taken' });
        return;
      }
      updateFields.slug = slugLower;
    }

    if (req.body.profileImageUrl !== undefined) updateFields.profileImageUrl = req.body.profileImageUrl;
    if (req.body.bannerImageUrl !== undefined) updateFields.bannerImageUrl = req.body.bannerImageUrl;
    if (req.body.location !== undefined) updateFields.location = req.body.location;
    if (req.body.socialLinks !== undefined) updateFields.socialLinks = req.body.socialLinks;
    if (req.body.isPublicStorefront !== undefined) updateFields.isPublicStorefront = req.body.isPublicStorefront;
    if (req.body.businessHours !== undefined) updateFields.businessHours = req.body.businessHours;

    const updated = await Merchant.findByIdAndUpdate(
      merchant._id,
      { $set: updateFields },
      { new: true }
    );

    res.json({ success: true, data: updated });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : 'Storefront update failed';
    res.status(500).json({ success: false, error: msg });
  }
});

// ── POST /api/v1/storefronts/:slug/review ────────────────────────────────────
router.post('/:slug/review', requireAuth, requireCustomer, validate(reviewSchema), async (req: Request, res: Response) => {
  try {
    const merchant = await Merchant.findOne({ slug: req.params.slug.toLowerCase(), isPublicStorefront: true, isActive: true });
    if (!merchant) {
      res.status(404).json({ success: false, error: 'Storefront not found' });
      return;
    }

    // Verify invoice belongs to customer and is confirmed or settled
    const invoice = await Invoice.findOne({
      invoiceId: req.body.invoiceId,
      customerId: req.user._id,
      merchantId: merchant._id,
    });

    if (!invoice) {
      res.status(404).json({ success: false, error: 'Escrow payment/invoice not found for this customer' });
      return;
    }

    const eligibleStates = ['Locked', 'PartiallyReleased', 'Released', 'Resolved'];
    const isEscrowConfirmed = eligibleStates.includes(invoice.escrowState);

    if (!isEscrowConfirmed) {
      res.status(400).json({ success: false, error: 'You can only review after funds have been locked in escrow' });
      return;
    }

    // Check duplicate review
    const duplicate = await Review.findOne({ invoiceId: req.body.invoiceId });
    if (duplicate) {
      res.status(400).json({ success: false, error: 'A review has already been submitted for this transaction' });
      return;
    }

    const review = await Review.create({
      invoiceId: req.body.invoiceId,
      merchantId: merchant._id,
      customerId: req.user._id,
      productId: req.body.productId,
      rating: req.body.rating,
      body: req.body.body,
      isVerified: true, // Tied to verified locked/resolved escrow
    });

    // Update product average rating if productId is provided
    if (req.body.productId) {
      const reviews = await Review.find({ productId: req.body.productId });
      const avg = reviews.reduce((sum, r) => sum + r.rating, 0) / reviews.length;
      await Product.findByIdAndUpdate(req.body.productId, { $set: { rating: parseFloat(avg.toFixed(1)) } });
    }

    res.status(201).json({ success: true, data: review });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : 'Failed to submit review';
    res.status(500).json({ success: false, error: msg });
  }
});

export default router;
