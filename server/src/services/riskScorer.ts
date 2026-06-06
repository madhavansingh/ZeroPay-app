import { upstashRedis } from '../config/redis';
import { Invoice } from '../models/Invoice';
import { Merchant } from '../models/Merchant';
import { logger } from '../config/logger';
import { env } from '../config/env';
import { GoogleGenAI } from '@google/genai';

export interface RiskProfile {
  riskScore: number;                 // 0 to 100
  isHighVelocity: boolean;           // Exceeded short-term rate
  isAnomalousAmount: boolean;        // Size deviates heavily from merchant avg
  isSuspiciousAddress: boolean;      // Wallet matches known templates/dispute lists
  riskFlags: string[];               // Categorized warning tags
  rationale: string;                 // Text explanation
  suggestedAction: 'approve' | 'hold' | 'block';
}

const ai = new GoogleGenAI({ apiKey: env.GEMINI_API_KEY });

export class RiskScorer {
  /**
   * Evaluates wallet velocity inside a Redis sliding window (1 hour window).
   * Checks both cumulative transaction count and cumulative sum in Lovelace.
   */
  public static async evaluateVelocity(
    walletAddress: string,
    amountLovelace: number
  ): Promise<{ isHighVelocity: boolean; flags: string[]; count: number; volumeAda: number }> {
    const windowSecs = 3600; // 1 hour sliding window
    const now = Date.now();
    const clearBefore = now - windowSecs * 1000;
    
    const countKey = `velocity:count:${walletAddress}`;
    const volumeKey = `velocity:volume:${walletAddress}`;

    try {
      // Clear out expired members
      await Promise.all([
        upstashRedis.zremrangebyscore(countKey, 0, clearBefore),
        upstashRedis.zremrangebyscore(volumeKey, 0, clearBefore),
      ]);

      // Add current transaction
      const memberId = `${now}-${Math.random().toString(36).slice(2, 6)}`;
      await Promise.all([
        upstashRedis.zadd(countKey, { score: now, member: memberId }),
        upstashRedis.zadd(volumeKey, { score: now, member: `${memberId}:${amountLovelace}` }),
      ]);

      // Set expiry on keys to auto-cleanup inactive wallets
      await Promise.all([
        upstashRedis.expire(countKey, windowSecs),
        upstashRedis.expire(volumeKey, windowSecs),
      ]);

      // Get count and sum within the window
      const rawCount = await upstashRedis.zcard(countKey);
      const volumeMembers = await (upstashRedis as any).zrange(volumeKey, 0, -1);
      
      let totalLovelace = 0;
      for (const m of volumeMembers) {
        const parts = m.split(':');
        const lovelaceStr = parts[parts.length - 1];
        totalLovelace += parseInt(lovelaceStr || '0', 10);
      }

      const totalAda = totalLovelace / 1_000_000;
      const flags: string[] = [];
      let isHighVelocity = false;

      // Rate limit parameters: Max 10 transactions/hr OR > 10,000 ADA lock/hr
      if (rawCount > 10) {
        isHighVelocity = true;
        flags.push('wallet:high-transaction-count');
      }
      if (totalAda > 10000) {
        isHighVelocity = true;
        flags.push('wallet:high-volume-locked');
      }

      return {
        isHighVelocity,
        flags,
        count: rawCount,
        volumeAda: totalAda,
      };
    } catch (err: any) {
      logger.warn('[RiskScorer] Redis velocity tracking error, continuing gracefully', { error: err.message });
      return { isHighVelocity: false, flags: [], count: 1, volumeAda: amountLovelace / 1_000_000 };
    }
  }

  /**
   * Core risk classification combining sliding windows, DB audits, and dynamic AI evaluation.
   */
  public static async analyzeTransaction(params: {
    walletAddress: string;
    amountLovelace: number;
    merchantId: string;
    invoiceId: string;
  }): Promise<RiskProfile> {
    const { walletAddress, amountLovelace, merchantId, invoiceId } = params;
    const amountAda = amountLovelace / 1_000_000;
    
    const flags: string[] = [];
    let baseScore = 5; // Default healthy score

    // 1. Evaluate Redis Velocity
    const velocityResult = await this.evaluateVelocity(walletAddress, amountLovelace);
    if (velocityResult.isHighVelocity) {
      baseScore += 35;
      flags.push(...velocityResult.flags);
    }

    // 2. Fetch Merchant History & Audit Dispute Ratios
    let disputeRate = 0;
    let merchantHistoryCount = 0;
    try {
      const merchant = await Merchant.findById(merchantId);
      if (merchant) {
        merchantHistoryCount = merchant.totalOrders ?? 0;
        const disputeCount = merchant.disputeCount ?? 0;
        disputeRate = merchantHistoryCount > 0 ? (disputeCount / merchantHistoryCount) * 100 : 0;

        if (disputeRate > 15 && merchantHistoryCount > 5) {
          baseScore += 20;
          flags.push('merchant:high-dispute-ratio');
        }
      }
    } catch (err: any) {
      logger.warn('[RiskScorer] MongoDB merchant history fetch error, skipping', { error: err.message });
    }

    // 3. Size Anomaly Check (Deviates heavily from historic invoice metrics)
    let isAnomalousAmount = false;
    try {
      const stats = await Invoice.aggregate([
        { $match: { merchantId: new mongoose.Types.ObjectId(merchantId), status: 'settled' } },
        { $group: { _id: null, avgAmount: { $avg: '$amountLovelace' }, count: { $sum: 1 } } }
      ]);
      
      if (stats[0] && stats[0].count >= 3) {
        const avg = stats[0].avgAmount;
        if (amountLovelace > avg * 4) {
          isAnomalousAmount = true;
          baseScore += 20;
          flags.push('invoice:anomalous-high-value');
        }
      }
    } catch {
      // Ignore database aggregation failure
    }

    // 4. Heuristic Suspicious Patterns
    const isSuspiciousAddress = walletAddress.startsWith('addr_test1qqqq') || walletAddress.endsWith('zzzz');
    if (isSuspiciousAddress) {
      baseScore += 30;
      flags.push('wallet:suspicious-address-pattern');
    }

    // Cap the deterministic base score at 95
    let finalScore = Math.min(95, baseScore);

    // 5. Conduct Deep AI Behavioral Scan for High-Value or High-Risk transactions
    let rationale = 'Transaction conforms to standard volume and speed profiles.';
    let suggestedAction: 'approve' | 'hold' | 'block' = 'approve';

    if (amountAda >= 1000 || finalScore >= 40) {
      try {
        logger.info('[RiskScorer] Running deep AI risk check via Gemini LLM', { invoiceId, amountAda, baseScore });
        
        const prompt = `Analyze this ZeroPay Cardano commerce transaction for potential fraud, systemic risk, or sybil attacks.
Transaction context:
- Invoice ID: ${invoiceId}
- Wallet Address: ${walletAddress}
- Locked Volume (ADA): ${amountAda} ADA
- Sliding Window Transactions (1hr): ${velocityResult.count}
- Sliding Window Sum (1hr): ${velocityResult.volumeAda} ADA
- Merchant Dispute Rate (%): ${disputeRate}%
- Determined Risk Flags: ${flags.join(', ') || 'None'}
- Computed Base Score (Heuristic): ${finalScore}/100

Respond in strict JSON with exactly three fields:
1. "aiScoreAdjustment" (integer from -20 to +25 based on wallet pattern evaluation)
2. "rationale" (string, max 300 characters, explaining the decision)
3. "suggestedAction" (string, must be either "approve", "hold", or "block")`;

        const response = await ai.models.generateContent({
          model: 'gemini-2.0-flash',
          contents: prompt,
          config: {
            responseMimeType: 'application/json',
          },
        });

        const resultText = response.text || '{}';
        const parsed = JSON.parse(resultText.trim());

        if (typeof parsed.aiScoreAdjustment === 'number') {
          finalScore = Math.max(0, Math.min(100, finalScore + parsed.aiScoreAdjustment));
        }
        if (parsed.rationale) {
          rationale = parsed.rationale;
        }
        if (parsed.suggestedAction) {
          suggestedAction = parsed.suggestedAction;
        }
      } catch (err: any) {
        logger.error('[RiskScorer] Deep AI scan failed, falling back to base score heuristics', { error: err.message });
      }
    }

    // Default suggestions based on numerical bounds if AI didn't explicitly override it
    if (suggestedAction === 'approve') {
      if (finalScore >= 80) suggestedAction = 'block';
      else if (finalScore >= 40) suggestedAction = 'hold';
    }

    return {
      riskScore: finalScore,
      isHighVelocity: velocityResult.isHighVelocity,
      isAnomalousAmount,
      isSuspiciousAddress,
      riskFlags: flags,
      rationale,
      suggestedAction,
    };
  }
}

import mongoose from 'mongoose';
