import * as Sentry from '@sentry/node';

export function initSentry(): void {
  const dsn = process.env.SENTRY_DSN;
  if (!dsn) return;

  Sentry.init({
    dsn,
    environment: process.env.NODE_ENV ?? 'development',
    tracesSampleRate: process.env.NODE_ENV === 'production' ? 0.1 : 1.0,
    integrations: [
      Sentry.mongooseIntegration(),
    ],
    beforeSend(event) {
      // Scrub auth headers from request data
      if (event.request?.headers?.['authorization']) {
        event.request.headers['authorization'] = '[Filtered]';
      }
      return event;
    },
  });
}

/** Express error handler — must be registered after all routes */
export { Sentry };
