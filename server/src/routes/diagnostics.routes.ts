import { Router } from 'express';
import mongoose from 'mongoose';
import { bullMqRedis } from '../config/redis';
import { txConfirmationQueue, receiptQueue, notificationQueue, expiryQueue, dailyStatsQueue } from '../queues/queue.definitions';
import { env } from '../config/env';

const router = Router();

// ── /health/blockchain — 30-second in-memory cache guard ─────────────────────
let blockchainCache: { status: string; latencyMs: number; detail: string; cachedAt: number } | null = null;
const BLOCKCHAIN_CACHE_TTL_MS = 30_000;

async function checkBlockchain(): Promise<{ status: string; latencyMs: number; detail: string }> {
  const now = Date.now();
  if (blockchainCache && now - blockchainCache.cachedAt < BLOCKCHAIN_CACHE_TTL_MS) {
    return { status: blockchainCache.status, latencyMs: blockchainCache.latencyMs, detail: blockchainCache.detail + ' (cached)' };
  }

  const start = Date.now();
  try {
    const network = env.BLOCKFROST_NETWORK;
    const baseUrl = network === 'mainnet'
      ? 'https://cardano-mainnet.blockfrost.io/api/v0'
      : `https://cardano-${network}.blockfrost.io/api/v0`;

    const res = await fetch(`${baseUrl}/health`, {
      headers: { project_id: env.BLOCKFROST_PROJECT_ID },
      signal: AbortSignal.timeout(8000),
    });
    const latencyMs = Date.now() - start;
    const ok = res.ok;
    const result = {
      status: ok ? 'ok' : 'degraded',
      latencyMs,
      detail: ok ? `Blockfrost ${network} reachable` : `HTTP ${res.status}`,
    };
    blockchainCache = { ...result, cachedAt: now };
    return result;
  } catch (err) {
    const latencyMs = Date.now() - start;
    const result = {
      status: 'down',
      latencyMs,
      detail: err instanceof Error ? err.message : 'Unknown error',
    };
    blockchainCache = { ...result, cachedAt: now };
    return result;
  }
}

// ── GET /health ───────────────────────────────────────────────────────────────
router.get('/', async (_req, res) => {
  const mongoStart = Date.now();
  const mongoConnected = mongoose.connection.readyState === 1;
  const mongoLatencyMs = Date.now() - mongoStart;

  let redisConnected = false;
  let redisLatencyMs = 0;
  try {
    const redisStart = Date.now();
    const ping = await bullMqRedis.ping();
    redisLatencyMs = Date.now() - redisStart;
    redisConnected = ping === 'PONG';
  } catch {
    redisConnected = false;
  }

  const isHealthy = mongoConnected && redisConnected;

  res.status(isHealthy ? 200 : 503).json({
    status: isHealthy ? 'healthy' : 'unhealthy',
    timestamp: new Date().toISOString(),
    env: env.NODE_ENV,
    network: env.BLOCKFROST_NETWORK,
    services: {
      mongodb: { status: mongoConnected ? 'ok' : 'down', latencyMs: mongoLatencyMs },
      redis: { status: redisConnected ? 'ok' : 'down', latencyMs: redisLatencyMs },
    },
  });
});

// ── GET /health/db ────────────────────────────────────────────────────────────
router.get('/db', async (_req, res) => {
  const start = Date.now();
  const state = mongoose.connection.readyState;
  const stateMap: Record<number, string> = { 0: 'disconnected', 1: 'connected', 2: 'connecting', 3: 'disconnecting' };
  const latencyMs = Date.now() - start;
  const ok = state === 1;

  res.status(ok ? 200 : 503).json({
    status: ok ? 'ok' : 'down',
    latencyMs,
    detail: stateMap[state] ?? 'unknown',
    readyState: state,
  });
});

// ── GET /health/redis ─────────────────────────────────────────────────────────
router.get('/redis', async (_req, res) => {
  const start = Date.now();
  try {
    const ping = await bullMqRedis.ping();
    const latencyMs = Date.now() - start;
    const ok = ping === 'PONG';
    res.status(ok ? 200 : 503).json({ status: ok ? 'ok' : 'degraded', latencyMs, detail: ping });
  } catch (err) {
    const latencyMs = Date.now() - start;
    res.status(503).json({ status: 'down', latencyMs, detail: err instanceof Error ? err.message : 'ping failed' });
  }
});

// ── GET /health/queues ────────────────────────────────────────────────────────
router.get('/queues', async (_req, res) => {
  try {
    const queues = [
      { name: 'tx-confirmation', queue: txConfirmationQueue },
      { name: 'receipt-generation', queue: receiptQueue },
      { name: 'notification-dispatch', queue: notificationQueue },
      { name: 'invoice-expiry', queue: expiryQueue },
      { name: 'daily-stats', queue: dailyStatsQueue },
    ];

    const results = await Promise.all(
      queues.map(async ({ name, queue }) => {
        const [waiting, active, failed, delayed] = await Promise.all([
          queue.getWaitingCount(),
          queue.getActiveCount(),
          queue.getFailedCount(),
          queue.getDelayedCount(),
        ]);
        return { name, waiting, active, failed, delayed };
      })
    );

    const hasFailures = results.some((q) => q.failed > 0);

    res.status(200).json({
      status: hasFailures ? 'degraded' : 'ok',
      queues: results,
    });
  } catch (err) {
    res.status(503).json({ status: 'down', detail: err instanceof Error ? err.message : 'queue check failed' });
  }
});

// ── GET /health/blockchain ────────────────────────────────────────────────────
router.get('/blockchain', async (_req, res) => {
  const result = await checkBlockchain();
  const statusCode = result.status === 'ok' ? 200 : result.status === 'degraded' ? 200 : 503;
  res.status(statusCode).json(result);
});

export default router;
