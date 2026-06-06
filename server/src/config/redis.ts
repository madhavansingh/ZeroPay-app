import IORedis from 'ioredis';
import { Redis } from '@upstash/redis';
import { env } from './env';
import { logger } from './logger';

// ─── HTTP Redis Mock (In-Memory replacement for Upstash REST client) ──────────
// This completely avoids any Upstash API request limit blockages locally
class InMemoryRedisMock {
  private store = new Map<string, any>();
  private timeouts = new Map<string, NodeJS.Timeout>();

  async get<T = any>(key: string): Promise<T | null> {
    const val = this.store.get(key);
    if (val === undefined) return null;
    return val as T;
  }

  async set(key: string, value: any, options?: { ex?: number }): Promise<'OK'> {
    this.store.set(key, value);
    if (this.timeouts.has(key)) {
      clearTimeout(this.timeouts.get(key)!);
      this.timeouts.delete(key);
    }
    if (options?.ex) {
      const timer = setTimeout(() => {
        this.store.delete(key);
        this.timeouts.delete(key);
      }, options.ex * 1000);
      this.timeouts.set(key, timer);
    }
    return 'OK';
  }

  async del(key: string): Promise<number> {
    if (this.timeouts.has(key)) {
      clearTimeout(this.timeouts.get(key)!);
      this.timeouts.delete(key);
    }
    return this.store.delete(key) ? 1 : 0;
  }

  async incr(key: string): Promise<number> {
    const current = this.store.get(key);
    const parsed = parseInt(current || '0', 10);
    const next = parsed + 1;
    this.store.set(key, next.toString());
    return next;
  }

  async expire(key: string, seconds: number): Promise<number> {
    if (!this.store.has(key)) return 0;
    if (this.timeouts.has(key)) {
      clearTimeout(this.timeouts.get(key)!);
      this.timeouts.delete(key);
    }
    const timer = setTimeout(() => {
      this.store.delete(key);
      this.timeouts.delete(key);
    }, seconds * 1000);
    this.timeouts.set(key, timer);
    return 1;
  }

  // Sorted sets mock implementation
  private getSortedSet(key: string): Array<{ score: number; member: string }> {
    if (!this.store.has(key)) {
      this.store.set(key, []);
    }
    return this.store.get(key);
  }

  async zremrangebyscore(key: string, min: number | string, max: number | string): Promise<number> {
    const list = this.getSortedSet(key);
    const minVal = typeof min === 'string' ? parseFloat(min) : min;
    const maxVal = typeof max === 'string' ? parseFloat(max) : max;
    const beforeLength = list.length;
    const filtered = list.filter(item => item.score < minVal || item.score > maxVal);
    this.store.set(key, filtered);
    return beforeLength - filtered.length;
  }

  async zadd(key: string, ...args: any[]): Promise<number> {
    const list = this.getSortedSet(key);
    let added = 0;
    
    if (args.length === 1 && typeof args[0] === 'object') {
      const { score, member } = args[0];
      const existingIdx = list.findIndex(item => item.member === member);
      if (existingIdx !== -1) {
        list[existingIdx].score = score;
      } else {
        list.push({ score, member });
        added++;
      }
    } else {
      const score = args[0];
      const member = args[1];
      const existingIdx = list.findIndex(item => item.member === member);
      if (existingIdx !== -1) {
        list[existingIdx].score = score;
      } else {
        list.push({ score, member });
        added++;
      }
    }
    list.sort((a, b) => a.score - b.score);
    return added;
  }

  async zcard(key: string): Promise<number> {
    return this.getSortedSet(key).length;
  }

  async zrange<T = string[]>(key: string, start: number, stop: number, options?: any): Promise<any> {
    const list = this.getSortedSet(key);
    const members = list.map(item => item.member);
    
    const startIdx = start < 0 ? members.length + start : start;
    const stopIdx = stop < 0 ? members.length + stop : stop;
    
    return members.slice(startIdx, stopIdx + 1);
  }
}

export const upstashRedis = env.NODE_ENV === 'production'
  ? new Redis({
      url: env.UPSTASH_REDIS_REST_URL,
      token: env.UPSTASH_REDIS_REST_TOKEN,
    })
  : (new InMemoryRedisMock() as any);

// ─── Dynamic IORedis (for BullMQ — connects to TLS or local TCP Redis) ────────
// Only applies TLS configurations when using secure "rediss://" connection protocol

let tempRedis: IORedis;
const isTls = env.UPSTASH_REDIS_TLS_URL.startsWith('rediss://');
const redisOptions: any = {
  maxRetriesPerRequest: null, // Required by BullMQ
  enableReadyCheck: false,
  retryStrategy: (times: number) => Math.min(times * 50, 2000),
};
if (isTls) {
  redisOptions.tls = {};
}

try {
  if (env.UPSTASH_REDIS_TLS_URL.includes(',')) {
    const nodes = env.UPSTASH_REDIS_TLS_URL.split(',').map((n) => n.trim());
    const clusterOptions: any = {
      redisOptions: {
        maxRetriesPerRequest: null,
        enableReadyCheck: false,
      }
    };
    if (isTls) {
      clusterOptions.redisOptions.tls = {};
    }
    tempRedis = new IORedis.Cluster(nodes, clusterOptions) as any;
    logger.info('BullMQ Redis Cluster initialized');
  } else {
    tempRedis = new IORedis(env.UPSTASH_REDIS_TLS_URL, redisOptions);
  }
} catch (err: any) {
  logger.error('Failed to initialize primary BullMQ Redis connection, attempting fallback', { detail: err.message });
  tempRedis = new IORedis(env.UPSTASH_REDIS_TLS_URL, {
    maxRetriesPerRequest: null,
    enableReadyCheck: false,
    ...(isTls ? { tls: {} } : {}),
    retryStrategy: (times) => Math.min(times * 100, 3000),
  });
}

export const bullMqRedis = tempRedis;

bullMqRedis.on('connect', () => logger.info('BullMQ Redis connected'));
bullMqRedis.on('error', (err) => logger.error('BullMQ Redis error', { detail: err instanceof Error ? err.message : String(err) }));

// ─── Cache keys & TTLs ────────────────────────────────────────────────────────

export const cacheKeys = {
  adaInrRate: () => 'price:ada-inr',
  adaInrRateFallback: () => 'price:ada-inr:last-known',
  merchantProfile: (merchantId: string) => `merchant:profile:${merchantId}`,
  dailyStats: (merchantId: string, date: string) => `stats:daily:${merchantId}:${date}`,
  rateLimitAuth: (ip: string) => `ratelimit:auth:${ip}`,
  rateLimitInvoice: (userId: string) => `ratelimit:invoice:${userId}`,
  rateLimitPayment: (userId: string) => `ratelimit:payment:${userId}`,
  rateLimitAI: (userId: string) => `ratelimit:ai:${userId}`,
  rateLimitUpload: (userId: string) => `ratelimit:upload:${userId}`,
  rateLimitDispute: (userId: string) => `ratelimit:dispute:${userId}`,
  storefrontProfile: (slug: string) => `storefront:${slug}`,
  marketplaceFeed: (city: string) => `marketplace:feed:${city}`,
  marketplaceTrending: () => 'marketplace:trending',
  reputation: (walletAddress: string) => `reputation:${walletAddress}`,
  rateLimitDeveloper: (keyId: string) => `ratelimit:developer:${keyId}`,
} as const;

export const cacheTtl = {
  adaInrRate: 60,          // 60 seconds
  merchantProfile: 300,    // 5 minutes
  dailyStats: 90000,       // 25 hours
  storefrontProfile: 600,  // 10 minutes
  marketplaceFeed: 300,    // 5 minutes
  marketplaceTrending: 60, // 1 minute
  reputation: 600,         // 10 minutes
} as const;
