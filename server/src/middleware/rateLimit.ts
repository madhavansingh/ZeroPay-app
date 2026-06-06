import { Request, Response, NextFunction } from 'express';
import { upstashRedis, cacheKeys } from '../config/redis';

interface RateLimitConfig {
  windowSeconds: number;
  maxRequests: number;
  keyFn: (req: Request) => string;
  errorMessage: string;
}

function createRateLimiter(config: RateLimitConfig) {
  return async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const key = config.keyFn(req);
      const current = await upstashRedis.incr(key);

      if (current === 1) {
        await upstashRedis.expire(key, config.windowSeconds);
      }

      if (current > config.maxRequests) {
        res.status(429).json({
          success: false,
          error: config.errorMessage,
          retryAfter: config.windowSeconds,
        });
        return;
      }

      res.setHeader('X-RateLimit-Limit', config.maxRequests);
      res.setHeader('X-RateLimit-Remaining', Math.max(0, config.maxRequests - current));
      next();
    } catch {
      // Redis failure — fail open (don't block legitimate requests)
      next();
    }
  };
}

// 10 auth requests per minute per IP
export const authRateLimit = createRateLimiter({
  windowSeconds: 60,
  maxRequests: 10,
  keyFn: (req) => cacheKeys.rateLimitAuth(req.ip ?? 'unknown'),
  errorMessage: 'Too many auth requests. Please wait a minute.',
});

// 30 invoices per hour per user
export const invoiceRateLimit = createRateLimiter({
  windowSeconds: 3600,
  maxRequests: 30,
  keyFn: (req) => cacheKeys.rateLimitInvoice(req.user?.id ?? req.ip ?? 'unknown'),
  errorMessage: 'Invoice creation limit reached. Try again in an hour.',
});

// 10 payment submissions per 10 minutes per user
export const paymentRateLimit = createRateLimiter({
  windowSeconds: 600,
  maxRequests: 10,
  keyFn: (req) => cacheKeys.rateLimitPayment(req.user?.id ?? req.ip ?? 'unknown'),
  errorMessage: 'Too many payment submissions. Please wait 10 minutes.',
});

// AI endpoints protection: Max 5 requests/min per user
export const aiRateLimit = createRateLimiter({
  windowSeconds: 60,
  maxRequests: 5,
  keyFn: (req) => cacheKeys.rateLimitAI(req.user?.id ?? req.ip ?? 'unknown'),
  errorMessage: 'Too many AI requests. Please try again in a minute.',
});

// Upload endpoint protection: Max 5 uploads/min per user
export const uploadRateLimit = createRateLimiter({
  windowSeconds: 60,
  maxRequests: 5,
  keyFn: (req) => cacheKeys.rateLimitUpload(req.user?.id ?? req.ip ?? 'unknown'),
  errorMessage: 'Too many upload attempts. Please try again in a minute.',
});

// Dispute action protection: Max 3 dispute actions per day per user
export const disputeRateLimit = createRateLimiter({
  windowSeconds: 86400,
  maxRequests: 3,
  keyFn: (req) => cacheKeys.rateLimitDispute(req.user?.id ?? req.ip ?? 'unknown'),
  errorMessage: 'Dispute threshold reached. Only 3 disputes can be raised per day.',
});
