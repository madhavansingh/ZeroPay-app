import { describe, it, expect, vi, beforeEach } from 'vitest';
import mongoose from 'mongoose';

// 1. Mock env variables to prevent schema validation crashes
vi.mock('../../src/config/env', () => ({
  env: {
    NODE_ENV: 'test',
  },
}));

// Mock logger
vi.mock('../../src/config/logger', () => ({
  logger: {
    info: vi.fn(),
    warn: vi.fn(),
    error: vi.fn(),
  },
}));

vi.mock('../../src/models/Juror', () => ({
  Juror: {
    find: vi.fn(),
    updateMany: vi.fn(),
    updateOne: vi.fn(),
    findOne: vi.fn(),
  },
}));

vi.mock('../../src/models/JurorVote', () => ({
  JurorVote: {
    find: vi.fn(),
    findOneAndUpdate: vi.fn(),
  },
}));

vi.mock('../../src/models/DisputeVerdict', () => {
  const mockVerdict = {
    invoiceId: 'INV-123',
    merchantSplitPercent: 50,
    customerSplitPercent: 50,
    status: 'pending',
    assignedJurors: [],
    save: vi.fn().mockResolvedValue({}),
  };
  return {
    DisputeVerdict: {
      findOne: vi.fn().mockResolvedValue(mockVerdict),
    },
  };
});

// Mock Event Bus
vi.mock('../../src/events/eventBus', () => ({
  domainEventBus: {
    publish: vi.fn(),
  },
  DomainEvents: {
    EscrowResolved: 'EscrowResolved',
  },
}));

import { assignJurorsToDispute, submitJurorVote, evaluateDisputeQuorum } from '../../src/services/arbitration.service';
import { Juror } from '../../src/models/Juror';
import { JurorVote } from '../../src/models/JurorVote';
import { DisputeVerdict } from '../../src/models/DisputeVerdict';
import { domainEventBus } from '../../src/events/eventBus';

describe('Decentralized Arbitration & Juror System (Sprint 3)', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('assignJurorsToDispute', () => {
    it('picks available idle jurors and assigns them to the dispute', async () => {
      const mockJuror1 = { userId: new mongoose.Types.ObjectId(), stakedReputation: 100 };
      const mockJuror2 = { userId: new mongoose.Types.ObjectId(), stakedReputation: 100 };
      const mockJuror3 = { userId: new mongoose.Types.ObjectId(), stakedReputation: 80 };

      vi.mocked(Juror.find).mockResolvedValueOnce([mockJuror1, mockJuror2, mockJuror3]);
      vi.mocked(Juror.updateMany).mockResolvedValueOnce({});

      const assigned = await assignJurorsToDispute('INV-123');

      expect(assigned.length).toBe(3);
      expect(Juror.find).toHaveBeenCalledWith(
        expect.objectContaining({ status: 'idle', stakedReputation: { $gte: 50 } })
      );
      expect(Juror.updateMany).toHaveBeenCalledWith(
        { userId: { $in: expect.any(Array) } },
        { $set: { status: 'assigned' } }
      );
    });
  });

  describe('evaluateDisputeQuorum and slash mechanism', () => {
    it('calculates average splits and slashes out-of-consensus juror', async () => {
      const juror1Id = new mongoose.Types.ObjectId();
      const juror2Id = new mongoose.Types.ObjectId();
      const juror3Id = new mongoose.Types.ObjectId();

      const mockVerdict = {
        invoiceId: 'INV-123',
        merchantSplitPercent: 50,
        customerSplitPercent: 50,
        status: 'pending',
        assignedJurors: [juror1Id, juror2Id, juror3Id],
        save: vi.fn().mockResolvedValue({}),
      };
      vi.mocked(DisputeVerdict.findOne).mockResolvedValueOnce(mockVerdict as any);

      // Votes: Juror 1 (80%), Juror 2 (75%), Juror 3 (40%)
      // Average merchant split: (80 + 75 + 40) / 3 = 195 / 3 = 65%
      // Deviation limit: 15% (so range is 50% - 80%). Juror 3 (40%) is out-of-consensus and slashed!
      const mockVotes = [
        { disputeId: 'INV-123', jurorId: juror1Id, recommendedMerchantSplitPct: 80 },
        { disputeId: 'INV-123', jurorId: juror2Id, recommendedMerchantSplitPct: 75 },
        { disputeId: 'INV-123', jurorId: juror3Id, recommendedMerchantSplitPct: 40 },
      ];
      vi.mocked(JurorVote.find).mockResolvedValueOnce(mockVotes as any);

      const juror1Record = { userId: juror1Id, stakedReputation: 100, disputesResolvedCount: 5, accuracyScore: 90 };
      const juror2Record = { userId: juror2Id, stakedReputation: 100, disputesResolvedCount: 2, accuracyScore: 100 };
      const juror3Record = { userId: juror3Id, stakedReputation: 100, disputesResolvedCount: 4, accuracyScore: 80 };

      vi.mocked(Juror.findOne)
        .mockResolvedValueOnce(juror1Record as any)
        .mockResolvedValueOnce(juror2Record as any)
        .mockResolvedValueOnce(juror3Record as any);

      const resolved = await evaluateDisputeQuorum('INV-123');

      expect(resolved).toBe(true);
      expect(mockVerdict.merchantSplitPercent).toBe(65);
      expect(mockVerdict.customerSplitPercent).toBe(35);
      expect(mockVerdict.status).toBe('accepted');
      expect(mockVerdict.save).toHaveBeenCalled();

      // Check slash of Juror 3 (reputation decreases by 20)
      expect(Juror.updateOne).toHaveBeenCalledWith(
        { userId: juror3Id },
        expect.objectContaining({
          $set: expect.objectContaining({
            stakedReputation: 80, // 100 - 20
          }),
        })
      );

      // Check reward of Juror 1 (reputation increases by 10)
      expect(Juror.updateOne).toHaveBeenCalledWith(
        { userId: juror1Id },
        expect.objectContaining({
          $set: expect.objectContaining({
            stakedReputation: 110, // 100 + 10
          }),
        })
      );

      // Verify domain event emitted
      expect(domainEventBus.publish).toHaveBeenCalledWith('EscrowResolved', expect.objectContaining({
        invoiceId: 'INV-123',
        merchantPayoutLovelace: 65,
        customerPayoutLovelace: 35,
      }));
    });
  });
});
