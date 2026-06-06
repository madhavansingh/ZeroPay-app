import { Request, Response, NextFunction } from 'express';
import { ZodError, ZodSchema } from 'zod';
import { logger } from '../config/logger';

type ValidateTarget = 'body' | 'query' | 'params';

export function validate(schema: ZodSchema, target: ValidateTarget = 'body') {
  return (req: Request, res: Response, next: NextFunction): void => {
    const result = schema.safeParse(req[target]);

    if (!result.success) {
      const errors = result.error instanceof ZodError
        ? result.error.flatten().fieldErrors
        : { _: ['Validation failed'] };

      const requestId = res.locals['requestId'] as string | undefined;
      logger.warn(`Validation failed on ${req.method} ${req.path}`, {
        requestId,
        target,
        errors: JSON.stringify(errors),
        payload: JSON.stringify(req[target]),
      });

      res.status(400).json({
        success: false,
        error: 'Validation failed',
        details: errors,
        requestId,
      });
      return;
    }

    // Replace target with coerced/parsed data
    req[target] = result.data;
    next();
  };
}
