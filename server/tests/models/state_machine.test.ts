import { describe, it, expect } from 'vitest';
import { isValidTransition, EscrowState } from '../../src/models/Invoice';

describe('Escrow State Machine Validation', () => {
  const allStates: EscrowState[] = [
    'None',
    'Created',
    'PendingApproval',
    'Locked',
    'PartiallyReleased',
    'Released',
    'Refunded',
    'Disputed',
    'Resolved',
  ];

  it('should allow staying in the same state', () => {
    for (const state of allStates) {
      expect(isValidTransition(state, state)).toBe(true);
    }
  });

  it('should allow valid transitions', () => {
    // None -> Created, Locked
    expect(isValidTransition('None', 'Created')).toBe(true);
    expect(isValidTransition('None', 'Locked')).toBe(true);

    // Created -> PendingApproval, Locked
    expect(isValidTransition('Created', 'PendingApproval')).toBe(true);
    expect(isValidTransition('Created', 'Locked')).toBe(true);

    // PendingApproval -> Locked
    expect(isValidTransition('PendingApproval', 'Locked')).toBe(true);

    // Locked -> PartiallyReleased, Released, Disputed, Refunded
    expect(isValidTransition('Locked', 'PartiallyReleased')).toBe(true);
    expect(isValidTransition('Locked', 'Released')).toBe(true);
    expect(isValidTransition('Locked', 'Disputed')).toBe(true);
    expect(isValidTransition('Locked', 'Refunded')).toBe(true);

    // PartiallyReleased -> PartiallyReleased, Released, Disputed, Refunded
    expect(isValidTransition('PartiallyReleased', 'Released')).toBe(true);
    expect(isValidTransition('PartiallyReleased', 'Disputed')).toBe(true);
    expect(isValidTransition('PartiallyReleased', 'Refunded')).toBe(true);

    // Disputed -> Resolved
    expect(isValidTransition('Disputed', 'Resolved')).toBe(true);
  });

  it('should disallow invalid transitions', () => {
    // Released is a terminal state
    expect(isValidTransition('Released', 'Locked')).toBe(false);
    expect(isValidTransition('Released', 'Disputed')).toBe(false);

    // Refunded is a terminal state
    expect(isValidTransition('Refunded', 'Locked')).toBe(false);

    // Resolved is a terminal state
    expect(isValidTransition('Resolved', 'Locked')).toBe(false);

    // None cannot jump directly to Released
    expect(isValidTransition('None', 'Released')).toBe(false);
    expect(isValidTransition('None', 'Disputed')).toBe(false);

    // Locked cannot transition back to Created or None
    expect(isValidTransition('Locked', 'Created')).toBe(false);
    expect(isValidTransition('Locked', 'None')).toBe(false);
  });
});
