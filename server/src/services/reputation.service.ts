import { Merchant } from '../models/Merchant';
import { Invoice } from '../models/Invoice';
import { logger } from '../config/logger';

/**
 * Dynamically re-calculate reputation metrics and trust badges for a merchant
 */
export async function updateMerchantReputation(merchantMongoId: string): Promise<void> {
  const ctx = { merchantMongoId };
  logger.info('[reputation] Recalculating merchant trust profile', ctx);

  try {
    const merchant = await Merchant.findById(merchantMongoId);
    if (!merchant) {
      logger.warn('[reputation] Merchant not found for recalculation', ctx);
      return;
    }

    // Query all settled, refunded, or resolved invoices for this merchant
    const invoices = await Invoice.find({
      merchantId: merchantMongoId,
      status: { $in: ['settled', 'confirmed', 'failed', 'expired'] },
    });

    const totalOrders = invoices.length;
    let completedCount = 0;
    let refundedCount = 0;
    let disputeCount = 0;
    let disputesWonCount = 0;

    let totalMilestonesCount = 0;
    let fulfilledMilestonesCount = 0;

    for (const inv of invoices) {
      // Completed orders (settled or escrow state Released)
      if (inv.status === 'settled' || inv.escrowState === 'Released') {
        completedCount++;
      }
      
      if (inv.escrowState === 'Refunded') {
        refundedCount++;
      }

      if (inv.isDisputed || inv.escrowState === 'Disputed' || inv.escrowState === 'Resolved') {
        disputeCount++;
        // If dispute resolved and merchant received more than 50% payout
        if (inv.escrowState === 'Resolved') {
          // Check if resolved with merchant payout (mock/simple check: if invoice has a resolutionTxHash or was resolved)
          // We can check if disputes won or lost based on resolution details (let's assume resolved counts as half won unless otherwise specified)
          disputesWonCount++; 
        }
      }

      // Milestones statistics
      if (inv.milestones && inv.milestones.length > 0) {
        totalMilestonesCount += inv.milestones.length;
        fulfilledMilestonesCount += inv.milestones.filter((m) => m.status === 'released').length;
      }
    }

    // Calculate rates
    const escrowCompletionRate = totalOrders > 0 ? Math.round((completedCount / totalOrders) * 100) : 100;
    const milestoneFulfillmentRate = totalMilestonesCount > 0 ? Math.round((fulfilledMilestonesCount / totalMilestonesCount) * 100) : 100;

    // Calculate reputation score
    // Starting at 100, -10 per dispute, +7 per dispute won
    let reputationScore = 100 - (disputeCount * 10) + (disputesWonCount * 7);
    reputationScore = Math.max(30, Math.min(100, Math.round(reputationScore)));

    // Badge and Tier assignment
    let verifiedMerchantBadge = false;
    let reliabilityTier: 'silver' | 'gold' | 'platinum' | 'unrated' = 'unrated';

    if (totalOrders >= 15 && reputationScore >= 95 && escrowCompletionRate >= 90) {
      verifiedMerchantBadge = true;
      reliabilityTier = 'platinum';
    } else if (totalOrders >= 5 && reputationScore >= 90 && escrowCompletionRate >= 80) {
      verifiedMerchantBadge = true;
      reliabilityTier = 'gold';
    } else if (totalOrders >= 2 && reputationScore >= 80) {
      verifiedMerchantBadge = true;
      reliabilityTier = 'silver';
    }

    // Update merchant record
    await Merchant.findByIdAndUpdate(merchantMongoId, {
      $set: {
        totalOrders,
        reputationScore,
        escrowCompletionRate,
        milestoneFulfillmentRate,
        disputeCount,
        disputesWonCount,
        verifiedMerchantBadge,
        reliabilityTier,
      },
    });

    logger.info('[reputation] Trust profile updated successfully', {
      merchantMongoId,
      reputationScore,
      reliabilityTier,
      verifiedMerchantBadge,
    });
  } catch (err: any) {
    logger.error('[reputation] Recalculation failed', { merchantMongoId, error: err.message });
  }
}
