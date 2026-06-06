import { Request, Response, NextFunction } from 'express';
import bcrypt from 'bcryptjs';
import { ApiKey, IApiKey, ApiPermission } from '../models/ApiKey';
import { logger } from '../config/logger';

// Augment Express Request
declare global {
  namespace Express {
    interface Request {
      apiKeyDoc?: IApiKey;
    }
  }
}

const RATE_LIMITS: Record<string, number> = {
  starter: 100,     // 100 req/min
  pro: 1000,        // 1000 req/min
  enterprise: 5000, // 5000 req/min
};

export function requireApiKey(...requiredPermissions: ApiPermission[]) {
  return async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const authHeader = req.headers.authorization;
      if (!authHeader?.startsWith('Bearer ZPKEY-')) {
        res.status(401).json({ success: false, error: 'Missing or invalid API key' });
        return;
      }

      const rawKey = authHeader.slice(7); // Remove 'Bearer '

      // Find all active, non-expired keys to compare against
      const candidates = await ApiKey.find({
        isActive: true,
        $or: [{ expiresAt: { $exists: false } }, { expiresAt: { $gt: new Date() } }],
      }).lean();

      let matchedKey: IApiKey | null = null;
      for (const candidate of candidates) {
        const isMatch = await bcrypt.compare(rawKey, candidate.keyHash);
        if (isMatch) {
          matchedKey = candidate as unknown as IApiKey;
          break;
        }
      }

      if (!matchedKey) {
        res.status(401).json({ success: false, error: 'Invalid API key' });
        return;
      }

      // Check permissions
      if (requiredPermissions.length > 0 && !matchedKey.permissions.includes('*')) {
        const hasAll = requiredPermissions.every((p) => matchedKey!.permissions.includes(p));
        if (!hasAll) {
          res.status(403).json({ success: false, error: 'Insufficient API key permissions' });
          return;
        }
      }

      req.apiKeyDoc = matchedKey;

      // Async update usage stats (fire-and-forget)
      ApiKey.updateOne(
        { _id: matchedKey._id },
        { $inc: { requestCount: 1 }, $set: { lastUsedAt: new Date() } }
      ).catch((err) => logger.warn('Failed to update API key usage', { detail: err.message }));

      next();
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'API key authentication failed';
      logger.error('API key auth error', { detail: msg });
      res.status(500).json({ success: false, error: 'Authentication error' });
    }
  };
}
