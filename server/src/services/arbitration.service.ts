import mongoose from 'mongoose';
import { Juror } from '../models/Juror';
import { JurorVote } from '../models/JurorVote';
import { DisputeVerdict } from '../models/DisputeVerdict';
import { Invoice } from '../models/Invoice';
import { domainEventBus, DomainEvents } from '../events/eventBus';
import { logger } from '../config/logger';

export async function assignJurorsToDispute(invoiceId: string): Promise<mongoose.Types.ObjectId[]> {
  logger.info('[Arbitration] Assigning jurors to dispute', { invoiceId });

  // 1. Fetch dispute verdict placeholder or create one
  let verdict = await DisputeVerdict.findOne({ invoiceId });
  if (!verdict) {
    verdict = new DisputeVerdict({
      invoiceId,
      merchantSplitPercent: 50,
      customerSplitPercent: 50,
      confidence: 1,
      reasoning: 'Initial juror pool placeholder',
      status: 'pending',
    });
  }

  // 2. Fetch idle jurors with staked reputation
  const availableJurors = await Juror.find({
    status: 'idle',
    stakedReputation: { $gte: 50 },
  });

  if (availableJurors.length < 3) {
    logger.warn('[Arbitration] Not enough idle jurors available to assign quorum', {
      available: availableJurors.length,
    });
    // For test fallback or simulation, we'll assign whatever is available, or mock user IDs
    if (availableJurors.length === 0) {
      // Mock 3 dummy juror IDs for simulation
      const mockIds = [
        new mongoose.Types.ObjectId(),
        new mongoose.Types.ObjectId(),
        new mongoose.Types.ObjectId(),
      ];
      verdict.assignedJurors = mockIds;
      await verdict.save();
      return mockIds;
    }
  }

  // 3. Shuffle and pick 3 random jurors
  const shuffled = availableJurors.sort(() => 0.5 - Math.random());
  const selected = shuffled.slice(0, 3);
  const jurorUserIds = selected.map((j) => j.userId);

  // 4. Update selected jurors status to 'assigned'
  await Juror.updateMany(
    { userId: { $in: jurorUserIds } },
    { $set: { status: 'assigned' } }
  );

  verdict.assignedJurors = jurorUserIds;
  await verdict.save();

  logger.info('[Arbitration] Jurors assigned successfully', {
    invoiceId,
    assignedCount: jurorUserIds.length,
  });

  return jurorUserIds;
}

export async function submitJurorVote(params: {
  invoiceId: string;
  jurorUserId: string;
  recommendedMerchantSplitPct: number;
  recommendedCustomerSplitPct: number;
  reasoning: string;
}): Promise<void> {
  const { invoiceId, jurorUserId, recommendedMerchantSplitPct, recommendedCustomerSplitPct, reasoning } = params;
  logger.info('[Arbitration] Submitting juror vote', { invoiceId, jurorUserId });

  const verdict = await DisputeVerdict.findOne({ invoiceId });
  if (!verdict) {
    throw new Error('Dispute verdict record not found for this invoice');
  }

  const isAssigned = verdict.assignedJurors?.some((id) => id.toString() === jurorUserId);
  if (!isAssigned) {
    throw new Error('Juror is not assigned to arbitrate this dispute');
  }

  // Record/update vote
  await JurorVote.findOneAndUpdate(
    { disputeId: invoiceId, jurorId: jurorUserId },
    {
      $set: {
        recommendedMerchantSplitPct,
        recommendedCustomerSplitPct,
        reasoning,
        votedAt: new Date(),
      },
    },
    { upsert: true, new: true }
  );

  // Evaluate quorum asynchronously
  evaluateDisputeQuorum(invoiceId).catch((err) => {
    logger.error('[Arbitration] Error evaluating dispute quorum', { invoiceId, error: err.message });
  });
}

export async function evaluateDisputeQuorum(invoiceId: string): Promise<boolean> {
  logger.info('[Arbitration] Evaluating dispute quorum', { invoiceId });

  const verdict = await DisputeVerdict.findOne({ invoiceId });
  if (!verdict) return false;

  const assignedCount = verdict.assignedJurors?.length || 0;
  if (assignedCount === 0) return false;

  // Fetch all juror votes cast
  const votes = await JurorVote.find({ disputeId: invoiceId });

  if (votes.length < assignedCount) {
    logger.info('[Arbitration] Dispute quorum not yet reached', {
      invoiceId,
      votesCast: votes.length,
      required: assignedCount,
    });
    return false;
  }

  // Quorum reached! Compute agreed splits (consensus)
  const totalMerchantPct = votes.reduce((sum, v) => sum + v.recommendedMerchantSplitPct, 0);
  const avgMerchantPct = Math.round(totalMerchantPct / votes.length);
  const avgCustomerPct = 100 - avgMerchantPct;

  logger.info('[Arbitration] Quorum consensus calculated', {
    invoiceId,
    agreedMerchantSplit: avgMerchantPct,
    agreedCustomerSplit: avgCustomerPct,
  });

  // Slash/reward jurors based on consensus alignment
  for (const vote of votes) {
    const isOut = Math.abs(vote.recommendedMerchantSplitPct - avgMerchantPct) > 15;
    const juror = await Juror.findOne({ userId: vote.jurorId });

    if (juror) {
      const oldRep = juror.stakedReputation;
      const oldAcc = juror.accuracyScore;
      const totalResolved = juror.disputesResolvedCount + 1;

      if (isOut) {
        // Out of consensus: Slash reputation
        const newRep = Math.max(0, oldRep - 20);
        const newAcc = Math.round((juror.accuracyScore * juror.disputesResolvedCount) / totalResolved);
        await Juror.updateOne(
          { userId: vote.jurorId },
          {
            $set: {
              stakedReputation: newRep,
              accuracyScore: newAcc,
              status: newRep === 0 ? 'suspended' : 'idle',
            },
            $inc: { disputesResolvedCount: 1 },
          }
        );
        logger.warn('[Arbitration] Juror slashed for out-of-consensus vote', {
          jurorId: vote.jurorId.toString(),
          oldRep,
          newRep,
        });
      } else {
        // In consensus: Reward reputation & increment accuracy score
        const newRep = oldRep + 10;
        const newAcc = Math.round((juror.accuracyScore * juror.disputesResolvedCount + 100) / totalResolved);
        await Juror.updateOne(
          { userId: vote.jurorId },
          {
            $set: {
              stakedReputation: newRep,
              accuracyScore: newAcc,
              status: 'idle',
            },
            $inc: { disputesResolvedCount: 1 },
          }
        );
        logger.info('[Arbitration] Juror rewarded for consensus alignment', {
          jurorId: vote.jurorId.toString(),
          oldRep,
          newRep,
        });
      }
    }
  }

  // Update verdict split values and set status to 'accepted' (meaning verdict is agreed)
  verdict.merchantSplitPercent = avgMerchantPct;
  verdict.customerSplitPercent = avgCustomerPct;
  verdict.status = 'accepted';
  verdict.reasoning = `Consensus dispute resolution agreed by ${votes.length} jurors.`;
  await verdict.save();

  // Reset any registered jurors to idle who weren't slashed/suspended
  const jurorUserIds = votes.map((v) => v.jurorId);
  await Juror.updateMany(
    { userId: { $in: jurorUserIds }, stakedReputation: { $gt: 0 } },
    { $set: { status: 'idle' } }
  );

  // Trigger EscrowResolved domain event (which builds/submits ledger entries)
  domainEventBus.publish(DomainEvents.EscrowResolved, {
    invoiceId,
    merchantPayoutLovelace: avgMerchantPct, // abstract percentage represent as split weight
    customerPayoutLovelace: avgCustomerPct,
    actorId: 'system-arbitration',
  });

  logger.info('[Arbitration] Dispute resolved successfully by quorum', { invoiceId });
  return true;
}
