import { EventEmitter } from 'events';
import { logger } from '../config/logger';

class DomainEventBus extends EventEmitter {
  constructor() {
    super();
    // Prevent unhandled error events from crashing the process
    this.on('error', (err) => {
      logger.error('[EventBus] Unhandled event error:', { detail: err.message });
    });
  }

  publish(event: string, payload: any): void {
    logger.info(`[EventBus] Publishing event: ${event}`, { eventType: event, ...payload });
    // Emit asynchronously using setImmediate so listeners don't block the caller
    setImmediate(() => {
      try {
        this.emit(event, payload);
      } catch (err: any) {
        logger.error(`[EventBus] Error executing subscribers for ${event}:`, { detail: err.message });
      }
    });
  }
}

export const domainEventBus = new DomainEventBus();

export const DomainEvents = {
  EscrowLocked: 'EscrowLocked',
  MilestoneReleased: 'MilestoneReleased',
  DisputeRaised: 'DisputeRaised',
  RefundCompleted: 'RefundCompleted',
  EscrowResolved: 'EscrowResolved',
  NotificationRequested: 'NotificationRequested',
} as const;
