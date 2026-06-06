import 'dotenv/config';
import { initSentry, Sentry } from './config/sentry';
// Init Sentry before everything else
initSentry();
import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import mongoose from 'mongoose';
import { randomUUID } from 'crypto';

import { env } from './config/env';
import { logger } from './config/logger';
import { connectDatabase } from './config/db';
import { initFirebase } from './config/firebase-admin';
import { bullMqRedis, upstashRedis } from './config/redis';
import { initSocketServer } from './config/socketServer';
import { validateStartup } from './config/startupValidation';

import authRoutes from './routes/auth.routes';
import courtRoutes from './routes/court.routes';
import merchantRoutes from './routes/merchant.routes';
import invoiceRoutes from './routes/invoice.routes';
import paymentRoutes from './routes/payment.routes';
import priceRoutes from './routes/price.routes';
import chatRoutes from './routes/chat.routes';
import dashboardRoutes from './routes/dashboard.routes';
import diagnosticsRouter from './routes/diagnostics.routes';
import escrowRoutes from './routes/escrow.routes';
import evidenceRoutes from './routes/evidence.routes';
import aiRoutes from './routes/ai.routes';
import developerRoutes from './routes/developer.routes';
import storefrontRoutes from './routes/storefront.routes';
import catalogRoutes from './routes/catalog.routes';
import webhookRoutes from './routes/webhook.routes';
import reputationRoutes from './routes/reputation.routes';
import analyticsRoutes from './routes/analytics.routes';
import marketplaceRoutes from './routes/marketplace.routes';
import opsRoutes from './routes/ops.routes';
import walletRoutes from './routes/wallet.routes';
import telemetryRoutes from './routes/telemetry.routes';
import projectRoutes from './routes/project.routes';
import githubAuditRoutes from './routes/githubAudit.routes';

import { initSubscribers } from './events/subscribers';
import { metricsCollector, createMetricsRouter } from './middleware/metrics.middleware';
import { noSqlSanitizer, strictContentType } from './middleware/security.middleware';

import { errorHandler, notFound } from './middleware/errorHandler';
import { requestContext } from './config/context';
import { prerenderMiddleware } from './middleware/prerender.middleware';

// ── Global error handlers (process-level safety net) ─────────────────────────
process.on('uncaughtException', (err: Error) => {
  logger.error('Uncaught exception — shutting down', { detail: err.message });
  Sentry.captureException(err);
  process.exit(1);
});

process.on('unhandledRejection', (reason: unknown) => {
  const msg = reason instanceof Error ? reason.message : String(reason);
  logger.error('Unhandled promise rejection', { detail: msg });
  Sentry.captureException(reason instanceof Error ? reason : new Error(msg));
  // Do not exit — log and continue for non-fatal rejections
});

async function bootstrap(): Promise<void> {
  // 1. Run environment and configuration validations
  validateStartup();

  // 2. Verify Upstash Redis REST connectivity in production
  if (env.NODE_ENV === 'production') {
    logger.info('[Redis] Verifying Upstash Redis REST endpoint connectivity...');
    try {
      await upstashRedis.get('ping-check');
      logger.info('[Redis] Upstash Redis REST endpoint verified online.');
    } catch (err: any) {
      logger.error('[Redis] Upstash Redis REST endpoint check failed', { detail: err.message });
      throw new Error(`Upstash Redis REST connection check failed: ${err.message}`);
    }
  }

  initFirebase();
  await connectDatabase();
  initSubscribers();

  // ── Mongoose connection lifecycle logging ──────────────────────────────────
  mongoose.connection.on('disconnected', () => logger.warn('MongoDB disconnected'));
  mongoose.connection.on('reconnected', () => logger.info('MongoDB reconnected'));
  mongoose.connection.on('error', (err) => logger.error('MongoDB error', { detail: err.message }));

  const app = express();
  app.set('trust proxy', 1);

  app.use(helmet({
    contentSecurityPolicy: env.NODE_ENV === 'production' ? undefined : false,
  }));
  app.use(
    cors({
      origin: env.ALLOWED_ORIGINS.split(',').map((o) => o.trim()),
      credentials: true,
    })
  );
  app.use(express.json({ limit: '10kb' }));
  app.use(express.urlencoded({ extended: true }));
  app.use(morgan(env.NODE_ENV === 'production' ? 'combined' : 'dev'));

  // ── Metrics collection ────────────────────────────────────────────────────
  app.use(metricsCollector);

  // ── Security Hardening Middleware ─────────────────────────────────────────
  app.use(noSqlSanitizer);
  app.use(strictContentType);

  // ── Request correlation ID + duration tracking ─────────────────────────────

  app.use((req: Request, res: Response, next: NextFunction) => {
    const requestId = (req.headers['x-request-id'] as string) || randomUUID();
    const correlationId = (req.headers['x-correlation-id'] as string) || randomUUID();
    res.locals['requestId'] = requestId;
    res.setHeader('x-request-id', requestId);
    res.setHeader('x-correlation-id', correlationId);

    const start = Date.now();
    res.on('finish', () => {
      const durationMs = Date.now() - start;
      logger.info(`${req.method} ${req.path} ${res.statusCode}`, { durationMs });
    });

    requestContext.run({ correlationId, requestId }, () => {
      next();
    });
  });


  // ── SEO Public Storefront Crawler Prerender ────────────────────────────────
  app.use(prerenderMiddleware);

  // ── Diagnostics / health / metrics routes ──────────────────────────────────
  app.use('/health', diagnosticsRouter);
  app.use('/metrics', createMetricsRouter());



  // ── API routes ────────────────────────────────────────────────────────────
  app.use('/api/v1/auth', authRoutes);
  app.use('/api/v1/court', courtRoutes);
  app.use('/api/v1/merchant', dashboardRoutes);
  app.use('/api/v1/merchant', merchantRoutes);
  app.use('/api/v1/invoices', invoiceRoutes);
  app.use('/api/v1/payments', paymentRoutes);
  app.use('/api/v1/price', priceRoutes);
  app.use('/api/v1/chat', chatRoutes);
  app.use('/api/v1/escrow', escrowRoutes);
  app.use('/api/v1/evidence', evidenceRoutes);
  app.use('/api/v1/ai', aiRoutes);
  app.use('/api/v1/developer', developerRoutes);
  app.use('/api/v1/storefronts', storefrontRoutes);
  app.use('/api/v1/catalog', catalogRoutes);
  app.use('/api/v1/webhooks', webhookRoutes);
  app.use('/api/v1/reputation', reputationRoutes);
  app.use('/api/v1/analytics', analyticsRoutes);
  app.use('/api/v1/marketplace', marketplaceRoutes);
  app.use('/api/v1/ops', opsRoutes);
  app.use('/api/v1/wallet', walletRoutes);
  app.use('/api/v1/telemetry', telemetryRoutes);
  app.use('/api/v1/projects', projectRoutes);
  app.use('/api/v1/github', githubAuditRoutes);

  // ── Sentry Error Handler (must be before custom error handlers) ───────────
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  app.use(Sentry.expressErrorHandler() as any);

  // ── 404 + Custom error handlers ──────────────────────────────────────────
  app.use(notFound);
  app.use(errorHandler);

  // ── Start server ──────────────────────────────────────────────────────────
  const server = app.listen(env.PORT, () => {
    logger.info(`ZeroPay API started`, { port: env.PORT, env: env.NODE_ENV, network: env.BLOCKFROST_NETWORK });
  });

  // ── Init Socket Server ─────────────────────────────────────────────────────
  initSocketServer(server, env.UPSTASH_REDIS_TLS_URL);

  // ── Graceful shutdown ─────────────────────────────────────────────────────
  const shutdown = async (signal: string): Promise<void> => {
    logger.info(`Graceful shutdown initiated`, { signal });

    server.close(async () => {
      logger.info('HTTP server closed — disconnecting dependencies...');

      await bullMqRedis.quit();
      logger.info('Redis connection closed');

      await mongoose.disconnect();
      logger.info('MongoDB connection closed');

      logger.info('Shutdown complete');
      process.exit(0);
    });

    // Force exit after 30s if graceful shutdown stalls
    setTimeout(() => {
      logger.error('Forced shutdown after 30s timeout');
      process.exit(1);
    }, 30_000);
  };

  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
}

bootstrap().catch((err: Error) => {
  logger.error('Bootstrap failed', { detail: err.message });
  process.exit(1);
});
