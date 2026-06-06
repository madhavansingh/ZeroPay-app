import axios from 'axios';
import { upstashRedis, cacheKeys, cacheTtl } from '../config/redis';
import type { AdaInrRate } from '@zeropay/shared-types';

const COINGECKO_URL =
  'https://api.coingecko.com/api/v3/simple/price?ids=cardano&vs_currencies=inr';

export async function getAdaInrRate(): Promise<AdaInrRate> {
  // 1. Try Redis cache (60s TTL)
  const cached = await upstashRedis.get<{ rate: number; cachedAt: string }>(
    cacheKeys.adaInrRate()
  );

  if (cached) {
    return { ...cached, source: 'cached' };
  }

  // 2. Fetch from CoinGecko
  try {
    const response = await axios.get<{ cardano: { inr: number } }>(COINGECKO_URL, {
      timeout: 5000,
      headers: { Accept: 'application/json' },
    });

    const rate = response.data.cardano.inr;
    const cachedAt = new Date().toISOString();

    // Store in live cache + fallback
    await Promise.all([
      upstashRedis.set(cacheKeys.adaInrRate(), { rate, cachedAt }, { ex: cacheTtl.adaInrRate }),
      upstashRedis.set(cacheKeys.adaInrRateFallback(), { rate, cachedAt }), // no TTL
    ]);

    return { rate, cachedAt, source: 'live' };
  } catch {
    // 3. CoinGecko down — use last-known fallback
    const fallback = await upstashRedis.get<{ rate: number; cachedAt: string }>(
      cacheKeys.adaInrRateFallback()
    );

    if (fallback) {
      return { ...fallback, source: 'fallback' };
    }

    throw new Error('ADA/INR rate unavailable — CoinGecko unreachable and no fallback stored');
  }
}

/**
 * Convert INR paise to lovelace.
 * Uses integer arithmetic throughout — no floats stored.
 *
 * Formula: lovelace = round((paise / 100) / adaInrRate * 1_000_000)
 */
export function paiseToLovelace(paise: number, adaInrRate: number): number {
  const inr = paise / 100;
  const ada = inr / adaInrRate;
  return Math.round(ada * 1_000_000);
}

/**
 * Convert lovelace to INR display string (₹ format).
 */
export function lovelaceToInrDisplay(lovelace: number, adaInrRate: number): string {
  const ada = lovelace / 1_000_000;
  const inr = ada * adaInrRate;
  return inr.toFixed(2);
}
