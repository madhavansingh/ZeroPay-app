import { describe, it, expect, vi, beforeEach } from 'vitest';
import mongoose from 'mongoose';
import escrowRouter from '../../src/routes/escrow.routes';
import { Invoice } from '../../src/models/Invoice';
import { GitHubAudit } from '../../src/models/GitHubAudit';
import { Transaction } from '../../src/models/Transaction';
import { Merchant } from '../../src/models/Merchant';

// Mock env variables
vi.mock('../../src/config/env', () => ({
  env: {
    NODE_ENV: 'test',
    DEV_AUTH_ENABLED: true,
  },
}));

// Mock ioredis
vi.mock('ioredis', () => {
  class MockRedis {
    on = vi.fn();
    info = vi.fn().mockResolvedValue('redis_version:7.0.0');
    ping = vi.fn().mockResolvedValue('PONG');
    get = vi.fn().mockResolvedValue(null);
    set = vi.fn().mockResolvedValue('OK');
    quit = vi.fn().mockResolvedValue('OK');
  }
  return {
    default: MockRedis,
    Redis: MockRedis,
  };
});

// Mock middlewares
vi.mock('../../src/middleware/auth', () => ({
  requireAuth: (req: any, res: any, next: any) => {
    req.user = {
      _id: new mongoose.Types.ObjectId('507f1f77bcf86cd799439011'),
      id: '507f1f77bcf86cd799439011',
    };
    next();
  },
}));

vi.mock('../../src/middleware/rateLimit', () => ({
  disputeRateLimit: (req: any, res: any, next: any) => {
    next();
  },
}));

vi.mock('../../src/middleware/risk.middleware', () => ({
  riskMiddleware: (req: any, res: any, next: any) => {
    next();
  },
}));

// Mock models
vi.mock('../../src/models/Invoice', () => ({
  Invoice: {
    findOne: vi.fn(),
    findByIdAndUpdate: vi.fn(),
  },
  isValidTransition: vi.fn().mockReturnValue(true),
}));

vi.mock('../../src/models/GitHubAudit', () => ({
  GitHubAudit: {
    findOne: vi.fn(),
  },
}));

vi.mock('../../src/models/Transaction', () => ({
  Transaction: {
    findOne: vi.fn(),
    create: vi.fn(),
  },
}));

vi.mock('../../src/models/Merchant', () => ({
  Merchant: {
    findById: vi.fn(),
  },
}));

// Mock services
vi.mock('../../src/services/escrow.service', () => ({
  buildLockTx: vi.fn(),
  buildReleaseMilestoneTx: vi.fn(),
  buildRaiseDisputeTx: vi.fn(),
  buildAdminResolveTx: vi.fn(),
}));

vi.mock('../../src/services/reputation.service', () => ({
  updateMerchantReputation: vi.fn(),
}));

vi.mock('../../src/services/invoice.service', () => ({
  injectChatMessage: vi.fn(),
  mirrorEscrowToFirebase: vi.fn(),
}));

// Mock event bus
vi.mock('../../src/events/eventBus', () => ({
  domainEventBus: {
    publish: vi.fn(),
  },
  DomainEvents: {
    EscrowLocked: 'EscrowLocked',
    MilestoneReleased: 'MilestoneReleased',
    DisputeRaised: 'DisputeRaised',
    EscrowResolved: 'EscrowResolved',
  },
}));

// Mock queues
vi.mock('../../src/queues/queue.definitions', () => ({
  enqueueNotification: vi.fn(),
  enqueueTxConfirmation: vi.fn(),
}));

// Mock chain adapters
vi.mock('../../src/adapters/chain', () => ({
  chainAdapterRegistry: {
    getAdapter: vi.fn().mockReturnValue({
      buildLockTx: vi.fn().mockResolvedValue({ txHex: 'mockLockTxHex' }),
      buildReleaseTx: vi.fn().mockResolvedValue({ txHex: 'mockReleaseTxHex' }),
      buildResolveTx: vi.fn().mockResolvedValue({ txHex: 'mockResolveTxHex' }),
    }),
  },
}));

// Mock logger
vi.mock('../../src/config/logger', () => ({
  logger: {
    info: vi.fn(),
    error: vi.fn(),
    warn: vi.fn(),
  },
}));

// Helper to run route
function runRoute(req: any): Promise<{ res: any; body: any }> {
  return new Promise((resolve, reject) => {
    const res: any = {};
    let resolved = false;

    const finish = (body?: any) => {
      if (!resolved) {
        resolved = true;
        resolve({ res, body });
      }
    };

    res.json = vi.fn().mockImplementation((body) => {
      finish(body);
      return res;
    });

    res.status = vi.fn().mockImplementation((code) => {
      res.statusCode = code;
      return res;
    });

    res.send = vi.fn().mockImplementation((body) => {
      finish(body);
      return res;
    });

    res.locals = { requestId: 'req-123' };

    escrowRouter(req, res, (err) => {
      if (err) {
        reject(err);
      } else {
        finish({ nextCalled: true });
      }
    });
  });
}

const VALID_CARDANO_ADDR = 'addr_test1qrr58k9m0xxxxxyyyyyzzzzz';
const VALID_TX_HASH = 'a0b1c2d3e4f5a0b1c2d3e4f5a0b1c2d3e4f5a0b1c2d3e4f5a0b1c2d3e4f56789';

describe('Escrow Audit Enforcement Gating Tests', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('POST /escrow/:invoiceId/release', () => {
    it('succeeds (200 OK) if invoice does NOT have projectPlanId (Classic Invoice bypass)', async () => {
      const mockInvoice = {
        invoiceId: 'INV-12345',
        customerId: new mongoose.Types.ObjectId('507f1f77bcf86cd799439011'),
        projectPlanId: null,
        auditRequired: false,
        network: 'cardano',
        amountLovelace: 5000000,
        milestoneIndex: 0,
        milestones: [{ milestoneId: 'M-1', status: 'pending' }],
      };

      vi.mocked(Invoice.findOne).mockResolvedValue(mockInvoice as any);
      const { buildReleaseMilestoneTx } = await import('../../src/services/escrow.service');
      vi.mocked(buildReleaseMilestoneTx).mockResolvedValue({ txHex: 'mockReleaseTxHex' } as any);

      const req = {
        method: 'POST',
        url: '/INV-12345/release',
        params: { invoiceId: 'INV-12345' },
        body: { customerAddress: VALID_CARDANO_ADDR },
      };

      const { res, body } = await runRoute(req);

      expect(Invoice.findOne).toHaveBeenCalledWith({ invoiceId: 'INV-12345' });
      expect(GitHubAudit.findOne).not.toHaveBeenCalled();
      expect(res.status).not.toHaveBeenCalledWith(403);
      expect(body).toEqual({ success: true, data: { txHex: 'mockReleaseTxHex' } });
    });

    it('returns 403 Forbidden if invoice has projectPlanId but no audit exists', async () => {
      const mockInvoice = {
        invoiceId: 'INV-12345',
        customerId: new mongoose.Types.ObjectId('507f1f77bcf86cd799439011'),
        projectPlanId: 'PLAN-999',
        auditRequired: true,
        network: 'cardano',
        amountLovelace: 5000000,
        milestoneIndex: 0,
        milestones: [{ milestoneId: 'M-1', status: 'pending' }],
      };

      vi.mocked(Invoice.findOne).mockResolvedValue(mockInvoice as any);
      vi.mocked(GitHubAudit.findOne).mockReturnValue({
        sort: vi.fn().mockResolvedValue(null),
      } as any);

      const req = {
        method: 'POST',
        url: '/INV-12345/release',
        params: { invoiceId: 'INV-12345' },
        body: { customerAddress: VALID_CARDANO_ADDR },
      };

      const { res, body } = await runRoute(req);

      expect(Invoice.findOne).toHaveBeenCalledWith({ invoiceId: 'INV-12345' });
      expect(GitHubAudit.findOne).toHaveBeenCalledWith({
        projectPlanId: 'PLAN-999',
        milestoneId: 'M-1',
        invoiceId: 'INV-12345',
      });
      expect(res.status).toHaveBeenCalledWith(403);
      expect(body).toEqual({
        success: false,
        error: 'Milestone release blocked. GitHub audit requirements not satisfied.',
      });
    });

    it('returns 403 Forbidden if audit exists but status is FAILED', async () => {
      const mockInvoice = {
        invoiceId: 'INV-12345',
        customerId: new mongoose.Types.ObjectId('507f1f77bcf86cd799439011'),
        projectPlanId: 'PLAN-999',
        auditRequired: true,
        network: 'cardano',
        amountLovelace: 5000000,
        milestoneIndex: 0,
        milestones: [{ milestoneId: 'M-1', status: 'pending' }],
      };

      const mockAudit = {
        auditStatus: 'FAILED',
        releaseConfidenceScore: 80,
      };

      vi.mocked(Invoice.findOne).mockResolvedValue(mockInvoice as any);
      vi.mocked(GitHubAudit.findOne).mockReturnValue({
        sort: vi.fn().mockResolvedValue(mockAudit),
      } as any);

      const req = {
        method: 'POST',
        url: '/INV-12345/release',
        params: { invoiceId: 'INV-12345' },
        body: { customerAddress: VALID_CARDANO_ADDR },
      };

      const { res, body } = await runRoute(req);

      expect(res.status).toHaveBeenCalledWith(403);
      expect(body.error).toContain('Milestone release blocked');
    });

    it('returns 403 Forbidden if audit exists and status is PASSED but releaseConfidenceScore < 70', async () => {
      const mockInvoice = {
        invoiceId: 'INV-12345',
        customerId: new mongoose.Types.ObjectId('507f1f77bcf86cd799439011'),
        projectPlanId: 'PLAN-999',
        auditRequired: true,
        network: 'cardano',
        amountLovelace: 5000000,
        milestoneIndex: 0,
        milestones: [{ milestoneId: 'M-1', status: 'pending' }],
      };

      const mockAudit = {
        auditStatus: 'PASSED',
        releaseConfidenceScore: 65,
      };

      vi.mocked(Invoice.findOne).mockResolvedValue(mockInvoice as any);
      vi.mocked(GitHubAudit.findOne).mockReturnValue({
        sort: vi.fn().mockResolvedValue(mockAudit),
      } as any);

      const req = {
        method: 'POST',
        url: '/INV-12345/release',
        params: { invoiceId: 'INV-12345' },
        body: { customerAddress: VALID_CARDANO_ADDR },
      };

      const { res, body } = await runRoute(req);

      expect(res.status).toHaveBeenCalledWith(403);
      expect(body.error).toContain('Milestone release blocked');
    });

    it('succeeds (200 OK) if audit status is PASSED and releaseConfidenceScore >= 70', async () => {
      const mockInvoice = {
        invoiceId: 'INV-12345',
        customerId: new mongoose.Types.ObjectId('507f1f77bcf86cd799439011'),
        projectPlanId: 'PLAN-999',
        auditRequired: true,
        network: 'cardano',
        amountLovelace: 5000000,
        milestoneIndex: 0,
        milestones: [{ milestoneId: 'M-1', status: 'pending' }],
      };

      const mockAudit = {
        auditStatus: 'PASSED',
        releaseConfidenceScore: 75,
      };

      vi.mocked(Invoice.findOne).mockResolvedValue(mockInvoice as any);
      vi.mocked(GitHubAudit.findOne).mockReturnValue({
        sort: vi.fn().mockResolvedValue(mockAudit),
      } as any);

      const { buildReleaseMilestoneTx } = await import('../../src/services/escrow.service');
      vi.mocked(buildReleaseMilestoneTx).mockResolvedValue({ txHex: 'mockReleaseTxHex' } as any);

      const req = {
        method: 'POST',
        url: '/INV-12345/release',
        params: { invoiceId: 'INV-12345' },
        body: { customerAddress: VALID_CARDANO_ADDR },
      };

      const { res, body } = await runRoute(req);

      expect(res.status).not.toHaveBeenCalledWith(403);
      expect(body).toEqual({ success: true, data: { txHex: 'mockReleaseTxHex' } });
    });
  });

  describe('POST /escrow/:invoiceId/release/submit', () => {
    it('returns 403 Forbidden if invoice has projectPlanId but no audit exists', async () => {
      const mockInvoice = {
        invoiceId: 'INV-12345',
        customerId: new mongoose.Types.ObjectId('507f1f77bcf86cd799439011'),
        projectPlanId: 'PLAN-999',
        auditRequired: true,
        network: 'cardano',
        amountLovelace: 5000000,
        milestoneIndex: 0,
        milestones: [{ milestoneId: 'M-1', status: 'pending' }],
      };

      vi.mocked(Invoice.findOne).mockResolvedValue(mockInvoice as any);
      vi.mocked(GitHubAudit.findOne).mockReturnValue({
        sort: vi.fn().mockResolvedValue(null),
      } as any);

      const req = {
        method: 'POST',
        url: '/INV-12345/release/submit',
        params: { invoiceId: 'INV-12345' },
        body: { txHash: VALID_TX_HASH, payoutLovelace: 1000000 },
      };

      const { res, body } = await runRoute(req);

      expect(res.status).toHaveBeenCalledWith(403);
      expect(body).toEqual({
        success: false,
        error: 'Milestone release blocked. GitHub audit requirements not satisfied.',
      });
    });

    it('succeeds if audit status is PASSED and releaseConfidenceScore >= 70', async () => {
      const mockInvoice = {
        _id: new mongoose.Types.ObjectId(),
        invoiceId: 'INV-12345',
        customerId: new mongoose.Types.ObjectId('507f1f77bcf86cd799439011'),
        projectPlanId: 'PLAN-999',
        auditRequired: true,
        network: 'cardano',
        amountLovelace: 5000000,
        milestoneIndex: 0,
        totalMilestones: 2,
        milestones: [{ milestoneId: 'M-1', status: 'pending' }, { milestoneId: 'M-2', status: 'pending' }],
      };

      const mockAudit = {
        auditStatus: 'PASSED',
        releaseConfidenceScore: 72,
      };

      vi.mocked(Invoice.findOne).mockResolvedValue(mockInvoice as any);
      vi.mocked(GitHubAudit.findOne).mockReturnValue({
        sort: vi.fn().mockResolvedValue(mockAudit),
      } as any);

      const mockMerchant = {
        userId: new mongoose.Types.ObjectId(),
      };
      vi.mocked(Merchant.findById).mockResolvedValue(mockMerchant as any);

      const req = {
        method: 'POST',
        url: '/INV-12345/release/submit',
        params: { invoiceId: 'INV-12345' },
        body: { txHash: VALID_TX_HASH, payoutLovelace: 1000000 },
      };

      const { res, body } = await runRoute(req);

      expect(res.status).not.toHaveBeenCalledWith(403);
      expect(body.success).toBe(true);
    });
  });
});
