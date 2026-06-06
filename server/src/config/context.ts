import { AsyncLocalStorage } from 'async_hooks';
import { randomUUID } from 'crypto';

export interface RequestStore {
  correlationId: string;
  requestId?: string;
  invoiceId?: string;
  actorId?: string;
  merchantId?: string;
  [key: string]: string | undefined;
}

const contextStore = new AsyncLocalStorage<RequestStore>();

export const requestContext = {
  /**
   * Run a function bound inside the request-scoped tracing store context.
   */
  run<T>(store: RequestStore, fn: () => T): T {
    return contextStore.run(store, fn);
  },

  /**
   * Retrieve the current request-scoped tracing context.
   */
  getStore(): RequestStore | undefined {
    return contextStore.getStore();
  },

  /**
   * Get the current correlationId or auto-generate one if not in a store scope.
   */
  getCorrelationId(): string {
    const store = this.getStore();
    return store?.correlationId ?? `system-${randomUUID()}`;
  },

  /**
   * Set dynamic contextual keys into the current store (mutating context in-flight).
   */
  set(key: keyof RequestStore, value: string): void {
    const store = this.getStore();
    if (store) {
      store[key] = value;
    }
  },
};
