import { describe, it, expect, vi, beforeEach } from 'vitest';
import mongoose from 'mongoose';
import escrowRouter from '../../src/routes/escrow.routes';
import projectRouter from '../../src/routes/project.routes';
import githubAuditRouter from '../../src/routes/githubAudit.routes';
import invoiceRouter from '../../src/routes/invoice.routes';
import { Invoice } from '../../src/models/Invoice';
import { ProjectPlan } from '../../src/models/ProjectPlan';
import { GitHubAudit } from '../../src/models/GitHubAudit';
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

// Mock current user dynamically
let mockCurrentUser = {
  _id: new mongoose.Types.ObjectId('507f1f77bcf86cd799439011'),
  id: '507f1f77bcf86cd799439011',
  role: 'customer' as string,
};

// Mock middlewares
vi.mock('../../src/middleware/auth', () => ({
  requireAuth: (req: any, res: any, next: any) => {
    req.user = mockCurrentUser;
    next();
  },
  requireMerchant: (req: any, res: any, next: any) => {
    if (mockCurrentUser.role !== 'merchant' && mockCurrentUser.role !== 'both') {
      res.status(403).json({ success: false, error: 'Merchant access required' });
      return;
    }
    next();
  },
}));

vi.mock('../../src/middleware/rateLimit', () => ({
  disputeRateLimit: (req: any, res: any, next: any) => next(),
  aiRateLimit: (req: any, res: any, next: any) => next(),
  invoiceRateLimit: (req: any, res: any, next: any) => next(),
}));

vi.mock('../../src/middleware/risk.middleware', () => ({
  riskMiddleware: (req: any, res: any, next: any) => next(),
}));

// Mock models
vi.mock('../../src/models/Invoice', () => ({
  Invoice: {
    findOne: vi.fn(),
    findByIdAndUpdate: vi.fn(),
  },
  isValidTransition: vi.fn().mockReturnValue(true),
}));

vi.mock('../../src/models/ProjectPlan', () => ({
  ProjectPlan: {
    findOne: vi.fn(),
    find: vi.fn(),
    create: vi.fn(),
  },
}));

vi.mock('../../src/models/GitHubAudit', () => ({
  GitHubAudit: {
    findOne: vi.fn(),
  },
}));

vi.mock('../../src/models/Merchant', () => ({
  Merchant: {
    findOne: vi.fn(),
    findById: vi.fn(),
  },
}));

// Mock services
vi.mock('../../src/services/escrow.service', () => ({
  buildLockTx: vi.fn().mockResolvedValue({ txHex: 'mockLockTxHex' }),
  buildReleaseMilestoneTx: vi.fn().mockResolvedValue({ txHex: 'mockReleaseTxHex' }),
  buildRaiseDisputeTx: vi.fn(),
  buildAdminResolveTx: vi.fn(),
}));

vi.mock('../../src/services/invoice.service', () => ({
  createInvoice: vi.fn(),
  getInvoiceById: vi.fn(),
  mirrorEscrowToFirebase: vi.fn(),
  injectChatMessage: vi.fn(),
}));

vi.mock('../../src/services/githubAudit.service', () => ({
  connectRepository: vi.fn().mockResolvedValue({ success: true }),
  runMilestoneAudit: vi.fn().mockResolvedValue({ status: 'PASSED' }),
}));

vi.mock('../../src/services/nemotron.service', () => ({
  generateProjectPlanWithNemotron: vi.fn(),
}));

vi.mock('../../src/events/eventBus', () => ({
  domainEventBus: { publish: vi.fn() },
  DomainEvents: { EscrowLocked: 'EscrowLocked', MilestoneReleased: 'MilestoneReleased' },
}));

vi.mock('../../src/queues/queue.definitions', () => ({
  enqueueNotification: vi.fn(),
  enqueueTxConfirmation: vi.fn(),
}));

vi.mock('../../src/adapters/chain', () => ({
  chainAdapterRegistry: {
    getAdapter: vi.fn().mockReturnValue({
      buildLockTx: vi.fn().mockResolvedValue({ txHex: 'mockLockTxHex' }),
      buildReleaseTx: vi.fn().mockResolvedValue({ txHex: 'mockReleaseTxHex' }),
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

// Router runners
function runEscrowRoute(req: any): Promise<{ res: any; body: any }> {
  return new Promise((resolve, reject) => {
    const res: any = {};
    let resolved = false;
    const finish = (body?: any) => {
      if (!resolved) { resolved = true; resolve({ res, body }); }
    };
    res.json = vi.fn().mockImplementation((body) => { finish(body); return res; });
    res.status = vi.fn().mockImplementation((code) => { res.statusCode = code; return res; });
    res.send = vi.fn().mockImplementation((body) => { finish(body); return res; });
    res.locals = { requestId: 'req-123' };
    escrowRouter(req, res, (err) => {
      if (err) reject(err); else finish({ nextCalled: true });
    });
  });
}

function runProjectRoute(req: any): Promise<{ res: any; body: any }> {
  return new Promise((resolve, reject) => {
    const res: any = {};
    let resolved = false;
    const finish = (body?: any) => {
      if (!resolved) { resolved = true; resolve({ res, body }); }
    };
    res.json = vi.fn().mockImplementation((body) => { finish(body); return res; });
    res.status = vi.fn().mockImplementation((code) => { res.statusCode = code; return res; });
    res.send = vi.fn().mockImplementation((body) => { finish(body); return res; });
    projectRouter(req, res, (err) => {
      if (err) reject(err); else finish({ nextCalled: true });
    });
  });
}

function runGithubAuditRoute(req: any): Promise<{ res: any; body: any }> {
  return new Promise((resolve, reject) => {
    const res: any = {};
    let resolved = false;
    const finish = (body?: any) => {
      if (!resolved) { resolved = true; resolve({ res, body }); }
    };
    res.json = vi.fn().mockImplementation((body) => { finish(body); return res; });
    res.status = vi.fn().mockImplementation((code) => { res.statusCode = code; return res; });
    res.send = vi.fn().mockImplementation((body) => { finish(body); return res; });
    githubAuditRouter(req, res, (err) => {
      if (err) reject(err); else finish({ nextCalled: true });
    });
  });
}

function runInvoiceRoute(req: any): Promise<{ res: any; body: any }> {
  return new Promise((resolve, reject) => {
    const res: any = {};
    let resolved = false;
    const finish = (body?: any) => {
      if (!resolved) { resolved = true; resolve({ res, body }); }
    };
    res.json = vi.fn().mockImplementation((body) => { finish(body); return res; });
    res.status = vi.fn().mockImplementation((code) => { res.statusCode = code; return res; });
    res.send = vi.fn().mockImplementation((body) => { finish(body); return res; });
    invoiceRouter(req, res, (err) => {
      if (err) reject(err); else finish({ nextCalled: true });
    });
  });
}

describe('ZeroPay REST API Security Gates & Ownership Verification Tests', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockCurrentUser = {
      _id: new mongoose.Types.ObjectId('507f1f77bcf86cd799439011'),
      id: '507f1f77bcf86cd799439011',
      role: 'customer',
    };
  });

  describe('P0 Critical: Escrow Release Protection', () => {
    it('returns 403 Forbidden for POST /escrow/:invoiceId/release if caller is not the customer owner', async () => {
      const mockInvoice = {
        invoiceId: 'INV-123',
        customerId: new mongoose.Types.ObjectId('507f1f77bcf86cd799439022'), // Different customer
        network: 'cardano',
        amountLovelace: 5000000,
        milestoneIndex: 0,
        milestones: [{ milestoneId: 'M-1', status: 'pending' }],
      };
      vi.mocked(Invoice.findOne).mockResolvedValue(mockInvoice as any);

      const req = {
        method: 'POST',
        url: '/INV-123/release',
        params: { invoiceId: 'INV-123' },
        body: { customerAddress: 'addr_test1qrr58k9m0xxxxxyyyyyzzzzz' },
      };

      const { res, body } = await runEscrowRoute(req);
      expect(res.status).toHaveBeenCalledWith(403);
      expect(body.error).toContain('Only the customer who owns this escrow can release funds');
    });

    it('returns 403 Forbidden for POST /escrow/:invoiceId/release/submit if caller is not the customer owner', async () => {
      const mockInvoice = {
        invoiceId: 'INV-123',
        customerId: new mongoose.Types.ObjectId('507f1f77bcf86cd799439022'), // Different customer
        network: 'cardano',
        amountLovelace: 5000000,
        milestoneIndex: 0,
        milestones: [{ milestoneId: 'M-1', status: 'pending' }],
      };
      vi.mocked(Invoice.findOne).mockResolvedValue(mockInvoice as any);

      const req = {
        method: 'POST',
        url: '/INV-123/release/submit',
        params: { invoiceId: 'INV-123' },
        body: { txHash: 'a0b1c2d3e4f5a0b1c2d3e4f5a0b1c2d3e4f5a0b1c2d3e4f5a0b1c2d3e4f56789' },
      };

      const { res, body } = await runEscrowRoute(req);
      expect(res.status).toHaveBeenCalledWith(403);
      expect(body.error).toContain('Only the customer who owns this escrow can release funds');
    });

    it('blocks release (returns 403) if auditRequired is true but projectPlanId is missing', async () => {
      const mockInvoice = {
        invoiceId: 'INV-123',
        customerId: mockCurrentUser._id,
        projectPlanId: null, // Omitted plan ID
        auditRequired: true, // Audit explicitly required
        network: 'cardano',
        amountLovelace: 5000000,
        milestoneIndex: 0,
        milestones: [{ milestoneId: 'M-1', status: 'pending' }],
      };
      vi.mocked(Invoice.findOne).mockResolvedValue(mockInvoice as any);

      const req = {
        method: 'POST',
        url: '/INV-123/release',
        params: { invoiceId: 'INV-123' },
        body: { customerAddress: 'addr_test1qrr58k9m0xxxxxyyyyyzzzzz' },
      };

      const { res, body } = await runEscrowRoute(req);
      expect(res.status).toHaveBeenCalledWith(403);
      expect(body.error).toContain('missing projectPlanId');
    });
  });

  describe('P1 High: Project Plan Ownership & Modification Restrictions', () => {
    it('returns 403 Forbidden for POST /plan/:planId/approve if calling merchant does not own the plan', async () => {
      mockCurrentUser.role = 'merchant';
      const mockMerchant = {
        _id: new mongoose.Types.ObjectId('507f1f77bcf86cd799439055'), // Calling merchant
      };
      vi.mocked(Merchant.findOne).mockResolvedValue(mockMerchant as any);

      const mockPlan = {
        planId: 'PLAN-123',
        merchantId: new mongoose.Types.ObjectId('507f1f77bcf86cd799439066'), // Foreign merchant
        status: 'AI Generated',
        milestones: [],
      };
      vi.mocked(ProjectPlan.findOne).mockReturnValue({
        sort: vi.fn().mockResolvedValue(mockPlan),
      } as any);

      const req = {
        method: 'POST',
        url: '/plan/PLAN-123/approve',
        params: { planId: 'PLAN-123' },
        body: {},
      };

      const { res, body } = await runProjectRoute(req);
      expect(res.status).toHaveBeenCalledWith(403);
      expect(body.error).toContain('You do not own this project plan');
    });

    it('returns 403 Forbidden for PUT /plan/:planId if calling merchant does not own the plan', async () => {
      mockCurrentUser.role = 'merchant';
      const mockMerchant = {
        _id: new mongoose.Types.ObjectId('507f1f77bcf86cd799439055'),
      };
      vi.mocked(Merchant.findOne).mockResolvedValue(mockMerchant as any);

      const mockPlan = {
        planId: 'PLAN-123',
        merchantId: new mongoose.Types.ObjectId('507f1f77bcf86cd799439066'),
        status: 'AI Generated',
      };
      vi.mocked(ProjectPlan.findOne).mockReturnValue({
        sort: vi.fn().mockResolvedValue(mockPlan),
      } as any);

      const req = {
        method: 'PUT',
        url: '/plan/PLAN-123',
        params: { planId: 'PLAN-123' },
        body: {},
      };

      const { res, body } = await runProjectRoute(req);
      expect(res.status).toHaveBeenCalledWith(403);
      expect(body.error).toContain('You do not own this project plan');
    });
  });

  describe('P1 High: GitHub Audit Route Restrictions', () => {
    it('returns 403 Forbidden for POST /github/connect if calling merchant does not own the project plan', async () => {
      mockCurrentUser.role = 'merchant';
      const mockMerchant = {
        _id: new mongoose.Types.ObjectId('507f1f77bcf86cd799439055'),
      };
      vi.mocked(Merchant.findOne).mockResolvedValue(mockMerchant as any);

      const mockPlan = {
        planId: 'PLAN-123',
        merchantId: new mongoose.Types.ObjectId('507f1f77bcf86cd799439066'),
      };
      vi.mocked(ProjectPlan.findOne).mockResolvedValue(mockPlan as any);

      const req = {
        method: 'POST',
        url: '/connect',
        body: { projectPlanId: 'PLAN-123', repositoryUrl: 'https://github.com/test/repo' },
      };

      const { res, body } = await runGithubAuditRoute(req);
      expect(res.status).toHaveBeenCalledWith(403);
      expect(body.error).toContain('You do not own this project plan');
    });

    it('returns 403 Forbidden for POST /github/audit if calling merchant does not own the project plan', async () => {
      mockCurrentUser.role = 'merchant';
      const mockMerchant = {
        _id: new mongoose.Types.ObjectId('507f1f77bcf86cd799439055'),
      };
      vi.mocked(Merchant.findOne).mockResolvedValue(mockMerchant as any);

      const mockPlan = {
        planId: 'PLAN-123',
        merchantId: new mongoose.Types.ObjectId('507f1f77bcf86cd799439066'),
      };
      vi.mocked(ProjectPlan.findOne).mockResolvedValue(mockPlan as any);

      const req = {
        method: 'POST',
        url: '/audit',
        body: { projectPlanId: 'PLAN-123', milestoneId: 'MS-1' },
      };

      const { res, body } = await runGithubAuditRoute(req);
      expect(res.status).toHaveBeenCalledWith(403);
      expect(body.error).toContain('You do not own this project plan');
    });
  });

  describe('P2 Medium: Resource Access Control Restrictions', () => {
    it('returns 403 Forbidden for GET /plan/:planId if user is neither customer nor merchant associated with the plan', async () => {
      const mockMerchant = {
        _id: new mongoose.Types.ObjectId('507f1f77bcf86cd799439088'),
      };
      vi.mocked(Merchant.findOne).mockResolvedValue(mockMerchant as any);

      const mockPlan = {
        planId: 'PLAN-123',
        merchantId: new mongoose.Types.ObjectId('507f1f77bcf86cd799439066'), // Different merchant
        customerId: new mongoose.Types.ObjectId('507f1f77bcf86cd799439099'), // Different customer
      };
      vi.mocked(ProjectPlan.findOne).mockReturnValue({
        sort: vi.fn().mockResolvedValue(mockPlan),
      } as any);

      const req = {
        method: 'GET',
        url: '/plan/PLAN-123',
        params: { planId: 'PLAN-123' },
      };

      const { res, body } = await runProjectRoute(req);
      expect(res.status).toHaveBeenCalledWith(403);
      expect(body.error).toContain('You do not have permission to view this project plan');
    });

    it('returns 403 Forbidden for GET /api/v1/invoices/:invoiceId if user is neither customer nor merchant associated with the invoice', async () => {
      const mockMerchant = {
        _id: new mongoose.Types.ObjectId('507f1f77bcf86cd799439088'),
      };
      vi.mocked(Merchant.findById).mockResolvedValue(mockMerchant as any);

      const mockInvoice = {
        invoiceId: 'INV-123',
        merchantId: new mongoose.Types.ObjectId('507f1f77bcf86cd799439066'), // Different merchant
        customerId: new mongoose.Types.ObjectId('507f1f77bcf86cd799439099'), // Different customer
      };
      const { getInvoiceById } = await import('../../src/services/invoice.service');
      vi.mocked(getInvoiceById).mockResolvedValue(mockInvoice as any);

      const req = {
        method: 'GET',
        url: '/INV-123',
        params: { invoiceId: 'INV-123' },
      };

      const { res, body } = await runInvoiceRoute(req);
      expect(res.status).toHaveBeenCalledWith(403);
      expect(body.error).toContain('You do not have permission to view this invoice');
    });
  });
});
