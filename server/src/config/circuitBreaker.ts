import { logger } from './logger';

export type CircuitState = 'CLOSED' | 'OPEN' | 'HALF_OPEN';

export interface CircuitBreakerConfig {
  failureThreshold?: number;     // Number of failures before opening (default: 5)
  cooldownPeriodMs?: number;     // Time to wait in OPEN state before trying HALF_OPEN (default: 30,000ms)
  successThreshold?: number;     // Number of consecutive successes in HALF_OPEN to close (default: 2)
  timeoutMs?: number;            // Timeout for execution calls (default: 8,000ms)
}

export class CircuitBreaker {
  public readonly name: string;
  private state: CircuitState = 'CLOSED';
  private failureCount = 0;
  private successCount = 0;
  private lastStateChangeAt: number = Date.now();
  private lastFailureTime = 0;

  private readonly failureThreshold: number;
  private readonly cooldownPeriodMs: number;
  private readonly successThreshold: number;
  private readonly timeoutMs: number;

  constructor(name: string, config: CircuitBreakerConfig = {}) {
    this.name = name;
    this.failureThreshold = config.failureThreshold ?? 5;
    this.cooldownPeriodMs = config.cooldownPeriodMs ?? 30_000;
    this.successThreshold = config.successThreshold ?? 2;
    this.timeoutMs = config.timeoutMs ?? 8_000;
  }

  public getState(): CircuitState {
    this.checkCooldown();
    return this.state;
  }

  public getStats() {
    return {
      name: this.name,
      state: this.getState(),
      failureCount: this.failureCount,
      successCount: this.successCount,
      lastStateChangeAt: new Date(this.lastStateChangeAt).toISOString(),
    };
  }

  private transitionTo(newState: CircuitState): void {
    const oldState = this.state;
    this.state = newState;
    this.lastStateChangeAt = Date.now();
    
    logger.warn(`[CircuitBreaker] Circuit "${this.name}" transitioned states`, {
      breaker: this.name,
      oldState,
      newState,
      failureCount: this.failureCount,
    });
  }

  private checkCooldown(): void {
    if (this.state === 'OPEN' && Date.now() - this.lastStateChangeAt >= this.cooldownPeriodMs) {
      this.transitionTo('HALF_OPEN');
      this.successCount = 0;
      this.failureCount = 0;
    }
  }

  private recordSuccess(): void {
    if (this.state === 'HALF_OPEN') {
      this.successCount++;
      if (this.successCount >= this.successThreshold) {
        this.transitionTo('CLOSED');
        this.failureCount = 0;
      }
    } else if (this.state === 'CLOSED') {
      this.failureCount = 0; // reset on successful call
    }
  }

  private recordFailure(): void {
    this.failureCount++;
    this.lastFailureTime = Date.now();

    if (this.state === 'CLOSED') {
      if (this.failureCount >= this.failureThreshold) {
        this.transitionTo('OPEN');
      }
    } else if (this.state === 'HALF_OPEN') {
      // Any failure in HALF_OPEN immediately trips back to OPEN and resets cooldown
      this.transitionTo('OPEN');
    }
  }

  /**
   * Executes the provided async function inside a circuit breaker context.
   */
  public async execute<T>(fn: () => Promise<T>, fallback: T | ((error: Error) => Promise<T> | T)): Promise<T> {
    this.checkCooldown();

    if (this.state === 'OPEN') {
      logger.warn(`[CircuitBreaker] Blocked fast-fail execution on open breaker`, {
        breaker: this.name,
        cooldownRemainingMs: this.cooldownPeriodMs - (Date.now() - this.lastStateChangeAt),
      });
      return typeof fallback === 'function' 
        ? (fallback as Function)(new Error(`Circuit "${this.name}" is OPEN`)) 
        : fallback;
    }

    // Set up standard timeout abort signal wrapper
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), this.timeoutMs);

    try {
      const result = await Promise.race([
        fn(),
        new Promise<never>((_, reject) => {
          controller.signal.addEventListener('abort', () => {
            reject(new Error(`Execution on breaker "${this.name}" timed out after ${this.timeoutMs}ms`));
          });
        }),
      ]);

      clearTimeout(timeout);
      this.recordSuccess();
      return result;
    } catch (err: any) {
      clearTimeout(timeout);
      this.recordFailure();

      logger.error(`[CircuitBreaker] Breaker "${this.name}" caught failure during call`, {
        breaker: this.name,
        error: err.message,
        state: this.state,
        failureCount: this.failureCount,
      });

      return typeof fallback === 'function'
        ? (fallback as Function)(err)
        : fallback;
    }
  }
}

// ── Shared Registry ─────────────────────────────────────────────────────────
class CircuitBreakerRegistry {
  private breakers = new Map<string, CircuitBreaker>();

  public getOrCreate(name: string, config?: CircuitBreakerConfig): CircuitBreaker {
    let breaker = this.breakers.get(name);
    if (!breaker) {
      breaker = new CircuitBreaker(name, config);
      this.breakers.set(name, breaker);
      logger.info(`[CircuitBreaker] Registered breaker "${name}"`);
    }
    return breaker;
  }

  public getBreakers(): CircuitBreaker[] {
    return Array.from(this.breakers.values());
  }
}

export const circuitRegistry = new CircuitBreakerRegistry();
