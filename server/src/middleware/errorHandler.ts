import { Request, Response, NextFunction } from 'express';
import { ZodError } from 'zod';
import { logger } from '../config/logger';

export function errorHandler(
  err: Error,
  req: Request,
  res: Response,
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  _next: NextFunction
): void {
  const requestId = res.locals['requestId'] as string | undefined;
  logger.error(`${req.method} ${req.path} — unhandled error`, {
    requestId,
    errorName: err.name,
    detail: err.message,
  });

  // Zod validation error
  if (err instanceof ZodError) {
    res.status(400).json({
      success: false,
      error: 'Validation failed',
      fieldErrors: err.flatten().fieldErrors,
      requestId,
    });
    return;
  }

  // Mongoose validation error
  if (err.name === 'ValidationError') {
    res.status(400).json({ success: false, error: err.message, requestId });
    return;
  }

  // Mongoose duplicate key
  if (err.name === 'MongoServerError' && (err as any).code === 11000) {
    res.status(409).json({ success: false, error: 'Duplicate entry', requestId });
    return;
  }

  // JWT / Auth errors
  if (err.name === 'JsonWebTokenError' || err.name === 'TokenExpiredError') {
    res.status(401).json({ success: false, error: 'Invalid or expired token', requestId });
    return;
  }

  // Rate limit errors (express-rate-limit surfaces these as 429)
  if ((err as any).status === 429) {
    res.status(429).json({ success: false, error: 'Too many requests', requestId });
    return;
  }

  // Default 500
  res.status(500).json({
    success: false,
    error: process.env.NODE_ENV === 'production' ? 'Internal server error' : err.message,
    requestId,
  });
}

export function notFound(req: Request, res: Response): void {
  res.status(404).json({
    success: false,
    error: `Route ${req.method} ${req.path} not found`,
    requestId: res.locals['requestId'] as string | undefined,
  });
}
