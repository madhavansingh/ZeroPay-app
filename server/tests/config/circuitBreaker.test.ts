import { describe, it, expect, vi, beforeEach } from 'vitest';
import { CircuitBreaker } from '../../src/config/circuitBreaker';

describe('Resilient Circuit Breaker State Machine', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  it('should successfully execute functions and stay CLOSED on success', async () => {
    const breaker = new CircuitBreaker('test-success', {
      failureThreshold: 2,
      cooldownPeriodMs: 1000,
    });

    const mockFn = vi.fn().mockResolvedValue('success-payload');
    const result = await breaker.execute(mockFn, 'fallback-val');

    expect(result).toBe('success-payload');
    expect(mockFn).toHaveBeenCalledTimes(1);
    expect(breaker.getState()).toBe('CLOSED');
  });

  it('should transition to OPEN and fail fast after threshold is reached', async () => {
    const breaker = new CircuitBreaker('test-tripping', {
      failureThreshold: 2,
      cooldownPeriodMs: 10000,
    });

    const failingFn = vi.fn().mockRejectedValue(new Error('Network drop'));

    // First failure
    let result1 = await breaker.execute(failingFn, 'fallback-1');
    expect(result1).toBe('fallback-1');
    expect(breaker.getState()).toBe('CLOSED');

    // Second failure - trips the breaker
    let result2 = await breaker.execute(failingFn, 'fallback-2');
    expect(result2).toBe('fallback-2');
    expect(breaker.getState()).toBe('OPEN');

    // Third call - should fail fast immediately without even invoking the function
    const mockSuccessFn = vi.fn().mockResolvedValue('should-not-run');
    let result3 = await breaker.execute(mockSuccessFn, 'fast-fail-fallback');

    expect(result3).toBe('fast-fail-fallback');
    expect(mockSuccessFn).not.toHaveBeenCalled();
    expect(breaker.getState()).toBe('OPEN');
  });

  it('should transition to HALF_OPEN after cooldown and CLOSE on consecutive successes', async () => {
    const breaker = new CircuitBreaker('test-recovery', {
      failureThreshold: 1,
      cooldownPeriodMs: 5000,
      successThreshold: 2,
    });

    const failingFn = vi.fn().mockRejectedValue(new Error('Outage'));

    // Trip the breaker
    await breaker.execute(failingFn, 'fallback');
    expect(breaker.getState()).toBe('OPEN');

    // Fast-forward time past cooldown period (5000ms)
    vi.advanceTimersByTime(5001);
    expect(breaker.getState()).toBe('HALF_OPEN');

    // First successful test in HALF_OPEN
    const testFn = vi.fn().mockResolvedValue('test-ok');
    const res1 = await breaker.execute(testFn, 'fallback');
    expect(res1).toBe('test-ok');
    expect(breaker.getState()).toBe('HALF_OPEN');

    // Second successful test in HALF_OPEN - should close breaker
    const res2 = await breaker.execute(testFn, 'fallback');
    expect(res2).toBe('test-ok');
    expect(breaker.getState()).toBe('CLOSED');
  });

  it('should trip back to OPEN immediately if test fails in HALF_OPEN', async () => {
    const breaker = new CircuitBreaker('test-relapse', {
      failureThreshold: 1,
      cooldownPeriodMs: 5000,
      successThreshold: 2,
    });

    const failingFn = vi.fn().mockRejectedValue(new Error('Outage'));

    // Trip the breaker
    await breaker.execute(failingFn, 'fallback');
    expect(breaker.getState()).toBe('OPEN');

    // Fast-forward past cooldown
    vi.advanceTimersByTime(5001);
    expect(breaker.getState()).toBe('HALF_OPEN');

    // Outage relapse - test fails
    const res = await breaker.execute(failingFn, 'test-fail-fallback');
    expect(res).toBe('test-fail-fallback');
    expect(breaker.getState()).toBe('OPEN');
  });
});
