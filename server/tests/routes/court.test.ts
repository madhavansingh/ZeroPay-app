import { describe, it, expect, vi, beforeEach } from 'vitest';
import mongoose from 'mongoose';
import courtRouter from '../../src/routes/court.routes';
import { DisputeVerdict } from '../../src/models/DisputeVerdict';
import { Invoice } from '../../src/models/Invoice';
import { User } from '../../src/models/User';
import { Merchant } from '../../src/models/Merchant';
import { JurorVote } from '../../src/models/JurorVote';
import { Evidence } from '../../src/models/Evidence';
import { Juror } from '../../src/models/Juror';
import { submitJurorVote } from '../../src/services/arbitration.service';
import { env } from '../../src/config/env';

// 1. Mock env variables
vi.mock('../../src/config/env', () => ({
  env: {
    NODE_ENV: 'development',
    DEV_AUTH_ENABLED: true,
  },
}));

// 2. Mock middleware
vi.mock('../../src/middleware/auth', () => ({
  requireAuth: (req: any, res: any, next: any) => {
    req.user = {
      _id: new mongoose.Types.ObjectId('507f1f77bcf86cd799439011'),
      displayName: 'Test Juror',
    };
    next();
  },
}));

// 3. Mock Models
vi.mock('../../src/models/DisputeVerdict', () => ({
  DisputeVerdict: {
    find: vi.fn(),
    findOne: vi.fn(),
  },
}));

vi.mock('../../src/models/Invoice', () => ({
  Invoice: {
    findOne: vi.fn(),
  },
}));

vi.mock('../../src/models/User', () => ({
  User: {
    find: vi.fn(),
    findById: vi.fn(),
  },
}));

vi.mock('../../src/models/Merchant', () => ({
  Merchant: {
    findById: vi.fn(),
  },
}));

vi.mock('../../src/models/JurorVote', () => ({
  JurorVote: {
    findOne: vi.fn(),
  },
}));

vi.mock('../../src/models/Evidence', () => ({
  Evidence: {
    findOne: vi.fn(),
    create: vi.fn(),
  },
}));

vi.mock('../../src/models/Juror', () => ({
  Juror: {
    findOne: vi.fn(),
    create: vi.fn(),
  },
}));

// 4. Mock arbitration service
vi.mock('../../src/services/arbitration.service', () => ({
  submitJurorVote: vi.fn(),
}));

// Helper to simulate request/response cycle on a router asynchronously
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

    courtRouter(req, res, (err) => {
      if (err) {
        reject(err);
      } else {
        finish({ nextCalled: true });
      }
    });
  });
}

describe('Court Litigation Routes', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    env.NODE_ENV = 'development';
    env.DEV_AUTH_ENABLED = true;
  });

  describe('GET /cases', () => {
    it('returns formatted case details matching client expectation', async () => {
      const mockVerdict = {
        invoiceId: 'DS-9281',
        merchantSplitPercent: 50,
        customerSplitPercent: 50,
        status: 'pending',
        assignedJurors: [new mongoose.Types.ObjectId('507f1f77bcf86cd799439011')],
        createdAt: new Date(),
      };

      const mockInvoice = {
        description: 'Mock Dispute Transfer Description',
        amountLovelace: 10000000,
        amountPaise: 0,
        customerId: new mongoose.Types.ObjectId(),
        merchantId: new mongoose.Types.ObjectId(),
      };

      vi.mocked(DisputeVerdict.find).mockReturnValue({
        sort: vi.fn().mockResolvedValue([mockVerdict]),
      } as any);
      vi.mocked(Invoice.findOne).mockResolvedValue(mockInvoice as any);
      vi.mocked(User.findById).mockResolvedValue({ displayName: 'Plaintiff User' } as any);
      vi.mocked(Merchant.findById).mockResolvedValue({ shopName: 'Defendant Merchant' } as any);
      vi.mocked(User.find).mockResolvedValue([{
        _id: mockVerdict.assignedJurors[0],
        displayName: 'Test Juror',
      }] as any);
      vi.mocked(JurorVote.findOne).mockResolvedValue(null);

      const req: any = { method: 'GET', url: '/cases', headers: {} };
      
      const { res, body } = await runRoute(req);

      expect(res.json).toHaveBeenCalled();
      expect(body).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            caseId: 'DS-9281',
            title: 'Mock Dispute Transfer Description',
            disputed_amount_units: 10000000,
            assetSymbol: 'ADA',
            plaintiffName: 'Plaintiff User',
            defendantName: 'Defendant Merchant',
            status: 'Deliberation',
          }),
        ])
      );
    });
  });

  describe('POST /evidence', () => {
    it('creates new evidence record successfully', async () => {
      vi.mocked(Invoice.findOne).mockResolvedValue({} as any);
      vi.mocked(Evidence.findOne).mockResolvedValue(null);
      vi.mocked(Evidence.create).mockResolvedValue({
        ipfsHash: 'ipfs-hash-xyz',
      } as any);

      const req: any = {
        method: 'POST',
        url: '/evidence',
        body: { case_id: 'DS-9281', evidence_hash: 'ipfs-hash-xyz' },
      };
      
      const { res } = await runRoute(req);

      expect(res.status).toHaveBeenCalledWith(201);
      expect(Evidence.create).toHaveBeenCalled();
    });
  });

  describe('POST /vote', () => {
    it('allows auto-assignment and records vote in development mode', async () => {
      const mockVerdict = {
        invoiceId: 'DS-9281',
        assignedJurors: [],
        save: vi.fn().mockResolvedValue({}),
      };
      vi.mocked(DisputeVerdict.findOne).mockResolvedValue(mockVerdict as any);
      vi.mocked(Juror.findOne).mockResolvedValue(null);
      vi.mocked(Juror.create).mockResolvedValue({} as any);

      const req: any = {
        method: 'POST',
        url: '/vote',
        body: { case_id: 'DS-9281', support_plaintiff: true, reasoning: 'Clear proof' },
      };
      
      const { res, body } = await runRoute(req);

      expect(mockVerdict.assignedJurors.length).toBe(1);
      expect(mockVerdict.save).toHaveBeenCalled();
      expect(submitJurorVote).toHaveBeenCalledWith(
        expect.objectContaining({
          invoiceId: 'DS-9281',
          recommendedCustomerSplitPct: 100,
          recommendedMerchantSplitPct: 0,
        })
      );
      expect(body).toEqual(
        expect.objectContaining({ success: true })
      );
    });

    it('rejects vote with 403 if not pre-assigned in production mode', async () => {
      env.NODE_ENV = 'production';
      env.DEV_AUTH_ENABLED = false;

      const mockVerdict = {
        invoiceId: 'DS-9281',
        assignedJurors: [new mongoose.Types.ObjectId()], // some other juror
        save: vi.fn().mockResolvedValue({}),
      };
      vi.mocked(DisputeVerdict.findOne).mockResolvedValue(mockVerdict as any);

      const req: any = {
        method: 'POST',
        url: '/vote',
        body: { case_id: 'DS-9281', support_plaintiff: true },
      };
      
      const { res } = await runRoute(req);

      expect(res.status).toHaveBeenCalledWith(403);
      expect(submitJurorVote).not.toHaveBeenCalled();
    });
  });
});
