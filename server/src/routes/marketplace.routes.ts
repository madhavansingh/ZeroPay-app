import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { Merchant } from '../models/Merchant';
import { Product } from '../models/Product';
import { Invoice } from '../models/Invoice';
import { validate } from '../middleware/validate';
import { upstashRedis, cacheKeys, cacheTtl } from '../config/redis';
import { logger } from '../config/logger';

const router = Router();

const feedQuerySchema = z.object({
  city: z.string().optional(),
  category: z.string().optional(),
  page: z.preprocess((val) => (val ? parseInt(val as string, 10) : 1), z.number().int().positive()),
  limit: z.preprocess((val) => (val ? parseInt(val as string, 10) : 20), z.number().int().positive()),
});

// ── GET /api/v1/marketplace/feed ─────────────────────────────────────────────
router.get(
  '/feed',
  validate(feedQuerySchema, 'query'),
  async (req: Request, res: Response): Promise<void> => {
    try {
      const { city, category, page, limit } = req.query as unknown as {
        city?: string;
        category?: string;
        page: number;
        limit: number;
      };

      const cacheKey = `${cacheKeys.marketplaceFeed(city || 'global')}:${category || 'all'}:${page}:${limit}`;

      // Try fetching from cache
      const cached = await upstashRedis.get(cacheKey);
      if (cached) {
        res.json({ success: true, data: cached, fromCache: true });
        return;
      }

      // MongoDB filter definition
      const filter: any = { isPublicStorefront: true, isActive: true };
      if (city) {
        filter['location.city'] = new RegExp(city, 'i');
      }
      if (category) {
        filter.category = category;
      }

      const merchants = await Merchant.find(filter);

      // Scoring algorithm:
      // score = reputationScore * 0.4 + recencyScore * 0.3 + activityScore * 0.2 + categoryMatchScore * 0.1
      const scored = merchants.map((m) => {
        const daysSinceCreation = (Date.now() - m.createdAt.getTime()) / (1000 * 60 * 60 * 24);
        const recencyScore = Math.max(0, Math.min(100, 100 - daysSinceCreation));
        const activityScore = Math.min(100, (m.totalOrders || 0) * 0.2);
        const reputationScore = m.reputationScore || 0;
        const categoryMatchScore = category ? 100 : 0;

        const score =
          reputationScore * 0.4 + recencyScore * 0.3 + activityScore * 0.2 + categoryMatchScore * 0.1;

        return {
          merchantId: m.merchantId,
          shopName: m.shopName,
          slug: m.slug,
          category: m.category,
          description: m.description,
          profileImageUrl: m.profileImageUrl,
          bannerImageUrl: m.bannerImageUrl,
          location: m.location,
          reputationScore: m.reputationScore,
          reliabilityTier: m.reliabilityTier,
          verifiedMerchantBadge: m.verifiedMerchantBadge,
          totalOrders: m.totalOrders,
          score: parseFloat(score.toFixed(2)),
        };
      });

      // Sort by score descending
      scored.sort((a, b) => b.score - a.score);

      // Apply manual pagination
      const total = scored.length;
      const totalPages = Math.ceil(total / limit);
      const paginated = scored.slice((page - 1) * limit, page * limit);

      const result = {
        merchants: paginated,
        pagination: {
          total,
          page,
          limit,
          totalPages,
        },
      };

      // Set to Redis cache
      await upstashRedis.set(cacheKey, result, { ex: cacheTtl.marketplaceFeed });

      res.json({ success: true, data: result, fromCache: false });
    } catch (err: any) {
      logger.error('Failed to query marketplace feed', { detail: err.message });
      res.status(500).json({ success: false, error: 'Internal server error', detail: err.message });
    }
  }
);

// ── GET /api/v1/marketplace/trending ─────────────────────────────────────────
router.get('/trending', async (_req, res) => {
  try {
    const cacheKey = cacheKeys.marketplaceTrending();

    const cached = await upstashRedis.get(cacheKey);
    if (cached) {
      res.json({ success: true, data: cached, fromCache: true });
      return;
    }

    // 1. Fetch top products (sorted by totalSold descending)
    const trendingProducts = await Product.find({ isActive: true })
      .sort({ totalSold: -1 })
      .limit(10)
      .populate('merchantId', 'shopName slug profileImageUrl location reputationScore');

    // 2. Fetch top merchants over last 24h settled volume
    const since = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const trendingStats = await Invoice.aggregate([
      {
        $match: {
          status: 'settled',
          settledAt: { $gte: since },
        },
      },
      {
        $group: {
          _id: '$merchantId',
          orderCount: { $sum: 1 },
          volumePaise: { $sum: '$amountPaise' },
        },
      },
      { $sort: { orderCount: -1 } },
      { $limit: 10 },
    ]);

    const merchantIds = trendingStats.map((item) => item._id);
    const merchants = await Merchant.find({
      _id: { $in: merchantIds },
      isPublicStorefront: true,
      isActive: true,
    }).select('merchantId shopName slug category profileImageUrl location reputationScore reliabilityTier verifiedMerchantBadge');

    const trendingMerchants = merchants.map((m) => {
      const stats = trendingStats.find((item) => item._id.toString() === m._id.toString());
      return {
        merchantId: m.merchantId,
        shopName: m.shopName,
        slug: m.slug,
        category: m.category,
        profileImageUrl: m.profileImageUrl,
        location: m.location,
        reputationScore: m.reputationScore,
        reliabilityTier: m.reliabilityTier,
        verifiedMerchantBadge: m.verifiedMerchantBadge,
        volumePaise24h: stats ? stats.volumePaise : 0,
        orderCount24h: stats ? stats.orderCount : 0,
      };
    });

    const result = {
      products: trendingProducts,
      merchants: trendingMerchants.sort((a, b) => b.volumePaise24h - a.volumePaise24h),
    };

    // Cache the trending result
    await upstashRedis.set(cacheKey, result, { ex: cacheTtl.marketplaceTrending });

    res.json({ success: true, data: result, fromCache: false });
  } catch (err: any) {
    logger.error('Failed to fetch trending marketplace items', { detail: err.message });
    res.status(500).json({ success: false, error: 'Internal server error', detail: err.message });
  }
});

// ── GET /api/v1/marketplace/search ───────────────────────────────────────────
router.get('/search', async (req, res) => {
  try {
    const q = req.query.q as string;
    if (!q || q.trim().length === 0) {
      res.status(400).json({ success: false, error: 'Query parameter "q" is required' });
      return;
    }

    const regex = new RegExp(q, 'i');

    // 1. Search Merchants
    const merchants = await Merchant.find({
      isPublicStorefront: true,
      isActive: true,
      $or: [
        { shopName: regex },
        { category: regex },
        { description: regex },
        { 'location.city': regex },
      ],
    }).select('merchantId shopName slug category description profileImageUrl location reputationScore reliabilityTier verifiedMerchantBadge');

    // 2. Search Products
    let products = await Product.find({
      isActive: true,
      $text: { $search: q },
    }).populate('merchantId', 'shopName slug location profileImageUrl');

    // Fallback if full-text search yielded nothing
    if (products.length === 0) {
      products = await Product.find({
        isActive: true,
        $or: [{ title: regex }, { description: regex }, { tags: regex }],
      }).populate('merchantId', 'shopName slug location profileImageUrl');
    }

    res.json({
      success: true,
      data: {
        merchants,
        products,
      },
    });
  } catch (err: any) {
    logger.error('Failed to execute marketplace search', { detail: err.message });
    res.status(500).json({ success: false, error: 'Internal server error', detail: err.message });
  }
});

// ── GET /api/v1/marketplace/categories ───────────────────────────────────────
router.get('/categories', async (_req, res) => {
  try {
    const categories = await Merchant.aggregate([
      { $match: { isPublicStorefront: true, isActive: true } },
      { $group: { _id: '$category', merchantCount: { $sum: 1 } } },
      { $project: { category: '$_id', merchantCount: 1, _id: 0 } },
    ]);

    res.json({
      success: true,
      data: categories,
    });
  } catch (err: any) {
    logger.error('Failed to get marketplace categories', { detail: err.message });
    res.status(500).json({ success: false, error: 'Internal server error', detail: err.message });
  }
});

// ── GET /api/v1/marketplace/nearby ───────────────────────────────────────────
router.get('/nearby', async (req, res) => {
  try {
    const { city } = req.query;
    if (!city || (city as string).trim().length === 0) {
      res.status(400).json({ success: false, error: 'City query parameter is required' });
      return;
    }

    const merchants = await Merchant.find({
      isPublicStorefront: true,
      isActive: true,
      'location.city': new RegExp(city as string, 'i'),
    }).sort({ reputationScore: -1 });

    res.json({
      success: true,
      data: merchants,
    });
  } catch (err: any) {
    logger.error('Failed to query nearby merchants', { detail: err.message });
    res.status(500).json({ success: false, error: 'Internal server error', detail: err.message });
  }
});

export default router;
