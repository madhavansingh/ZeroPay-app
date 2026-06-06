import { Router, Request, Response } from 'express';
import { randomBytes } from 'crypto';
import bcrypt from 'bcryptjs';
import { nanoid } from 'nanoid';
import { requireAuth, requireMerchant } from '../middleware/auth';
import { requireApiKey } from '../middleware/apiKey.middleware';
import { ApiKey } from '../models/ApiKey';
import { Merchant } from '../models/Merchant';
import { Invoice } from '../models/Invoice';
import { logger } from '../config/logger';

const router = Router();

// ── API Key Management (authenticated merchant) ──────────────────────────────

// POST /api/v1/developer/keys/create
router.post('/keys/create', requireAuth, requireMerchant, async (req: Request, res: Response) => {
  try {
    const merchant = await Merchant.findOne({ userId: req.user._id });
    if (!merchant) {
      res.status(404).json({ success: false, error: 'Merchant not found' });
      return;
    }

    const existingCount = await ApiKey.countDocuments({ merchantId: merchant._id, isActive: true });
    if (existingCount >= 5) {
      res.status(400).json({ success: false, error: 'Maximum 5 active API keys allowed' });
      return;
    }

    const { name, permissions } = req.body;
    if (!name || typeof name !== 'string' || name.length < 1 || name.length > 100) {
      res.status(400).json({ success: false, error: 'Name is required (1-100 chars)' });
      return;
    }

    const rawKey = `ZPKEY-${nanoid(32)}`;
    const keyHash = await bcrypt.hash(rawKey, 10);
    const keyId = `zpk_${nanoid(12)}`;

    const apiKey = await ApiKey.create({
      keyId,
      keyHash,
      merchantId: merchant._id,
      name,
      permissions: permissions || ['escrow:read', 'merchant:read'],
    });

    logger.info('API key created', { keyId, merchantId: merchant.merchantId });

    // Return plaintext key ONCE — never retrievable again
    res.status(201).json({
      success: true,
      data: {
        keyId: apiKey.keyId,
        key: rawKey,
        name: apiKey.name,
        permissions: apiKey.permissions,
        rateLimitTier: apiKey.rateLimitTier,
        createdAt: apiKey.createdAt,
        warning: 'Store this key securely. It cannot be retrieved again.',
      },
    });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : 'Failed to create API key';
    logger.error('API key creation failed', { detail: msg });
    res.status(500).json({ success: false, error: msg });
  }
});

// GET /api/v1/developer/keys
router.get('/keys', requireAuth, requireMerchant, async (req: Request, res: Response) => {
  try {
    const merchant = await Merchant.findOne({ userId: req.user._id });
    if (!merchant) {
      res.status(404).json({ success: false, error: 'Merchant not found' });
      return;
    }

    const keys = await ApiKey.find({ merchantId: merchant._id })
      .select('-keyHash')
      .sort({ createdAt: -1 });

    res.json({ success: true, data: keys });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : 'Failed to list API keys';
    res.status(500).json({ success: false, error: msg });
  }
});

// DELETE /api/v1/developer/keys/:keyId
router.delete('/keys/:keyId', requireAuth, requireMerchant, async (req: Request, res: Response) => {
  try {
    const merchant = await Merchant.findOne({ userId: req.user._id });
    if (!merchant) {
      res.status(404).json({ success: false, error: 'Merchant not found' });
      return;
    }

    const result = await ApiKey.findOneAndUpdate(
      { keyId: req.params.keyId, merchantId: merchant._id },
      { $set: { isActive: false } },
      { new: true }
    );

    if (!result) {
      res.status(404).json({ success: false, error: 'API key not found' });
      return;
    }

    logger.info('API key revoked', { keyId: req.params.keyId });
    res.json({ success: true, message: 'API key revoked' });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : 'Failed to revoke API key';
    res.status(500).json({ success: false, error: msg });
  }
});

// ── Developer API Endpoints (API key authenticated) ──────────────────────────

// GET /api/v1/developer/escrow/:invoiceId
router.get('/escrow/:invoiceId', requireApiKey('escrow:read'), async (req: Request, res: Response) => {
  try {
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
        escrowState: invoice.escrowState || 'None',
        amountLovelace: invoice.amountLovelace,
        milestoneIndex: invoice.milestoneIndex,
        totalMilestones: invoice.totalMilestones,
        isDisputed: invoice.isDisputed,
        createdAt: invoice.createdAt,
      },
    });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : 'Failed to fetch escrow status';
    res.status(500).json({ success: false, error: msg });
  }
});

// GET /api/v1/developer/merchant/:merchantId
router.get('/merchant/:merchantId', requireApiKey('merchant:read'), async (req: Request, res: Response) => {
  try {
    const merchant = await Merchant.findOne({ merchantId: req.params.merchantId, isActive: true })
      .select('merchantId shopName category description paymentAddress reputationScore reliabilityTier verifiedMerchantBadge totalOrders escrowCompletionRate');

    if (!merchant) {
      res.status(404).json({ success: false, error: 'Merchant not found' });
      return;
    }

    res.json({ success: true, data: merchant });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : 'Failed to fetch merchant';
    res.status(500).json({ success: false, error: msg });
  }
});

export default router;
