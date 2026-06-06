import { Request, Response, NextFunction } from 'express';
import { logger } from '../config/logger';

// ── NoSQL Injection Sanitizer ─────────────────────────────────────────────────
// Recursively removes keys starting with '$' or containing '.' to prevent
// MongoDB operator injection (e.g. { "$gt": "" } → {})

type AnyObject = Record<string, unknown>;

function sanitizeObject(obj: unknown): unknown {
  if (Array.isArray(obj)) {
    return obj.map(sanitizeObject);
  }
  if (obj !== null && typeof obj === 'object') {
    const clean: AnyObject = {};
    for (const [key, value] of Object.entries(obj as AnyObject)) {
      // Drop keys beginning with $ (MongoDB operators) or containing dots
      if (key.startsWith('$') || key.includes('.')) {
        logger.warn('[Security] Stripped potentially malicious key from request', { key });
        continue;
      }
      clean[key] = sanitizeObject(value);
    }
    return clean;
  }
  return obj;
}

/**
 * noSqlSanitizer — strips MongoDB operator injection attempts from
 * req.body, req.query, and req.params before reaching route handlers.
 */
export function noSqlSanitizer(
  req: Request,
  _res: Response,
  next: NextFunction
): void {
  if (req.body && typeof req.body === 'object') {
    req.body = sanitizeObject(req.body);
  }
  if (req.query && typeof req.query === 'object') {
    (req as any).query = sanitizeObject(req.query);
  }
  if (req.params && typeof req.params === 'object') {
    req.params = sanitizeObject(req.params) as Record<string, string>;
  }
  next();
}

/**
 * strictContentType — rejects non-JSON content types on state-changing
 * routes to reduce risks from unexpected MIME-type exploits.
 */
export function strictContentType(
  req: Request,
  res: Response,
  next: NextFunction
): void {
  const mutating = ['POST', 'PUT', 'PATCH'];
  if (mutating.includes(req.method)) {
    const ct = req.headers['content-type'] ?? '';
    // Allow multipart (file uploads) and standard JSON
    if (!ct.includes('application/json') && !ct.includes('multipart/form-data')) {
      res.status(415).json({
        success: false,
        error: 'Unsupported Media Type. Only application/json is accepted.',
      });
      return;
    }
  }
  next();
}
