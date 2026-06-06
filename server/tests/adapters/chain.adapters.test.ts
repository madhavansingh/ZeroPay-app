import { describe, it, expect, vi, beforeEach } from 'vitest';

// 1. Mock env variables to prevent schema validation crashes
vi.mock('../../src/config/env', () => ({
  env: {
    NODE_ENV: 'test',
    ESCROW_PLATFORM_FEE_LOVELACE: 2000000,
    ESCROW_ADMIN_ADDRESS: 'addr_test1qrr2cldldladmin',
    ESCROW_TREASURY_ADDRESS: 'addr_test1qrr2cldldltreasury',
    BLOCKFROST_PROJECT_ID: 'mock-project-id',
  },
}));

// Mock Mongoose models
vi.mock('../../src/models/Invoice', () => ({
  Invoice: {
    findOne: vi.fn(),
  },
}));

// Mock services
vi.mock('../../src/services/escrow.service', () => ({
  buildLockTx: vi.fn().mockResolvedValue({ unsignedCbor: 'lock-cbor', scriptAddress: 'script-addr' }),
  buildReleaseMilestoneTx: vi.fn().mockResolvedValue({ unsignedCbor: 'release-cbor' }),
  buildRefundTx: vi.fn().mockResolvedValue({ unsignedCbor: 'refund-cbor' }),
  buildAdminResolveTx: vi.fn().mockResolvedValue({ unsignedCbor: 'resolve-cbor' }),
  findActiveEscrowUtxo: vi.fn().mockResolvedValue({ txHash: 'hash', txIndex: 0, amountLovelace: 10000000, datum: {} }),
}));

vi.mock('../../src/services/blockchain.service', () => ({
  getTxInfo: vi.fn(),
  verifyPayment: vi.fn().mockReturnValue('amount-matched'),
}));

import { chainAdapterRegistry } from '../../src/adapters/chain';
import { CardanoAdapter } from '../../src/adapters/chain/cardanoAdapter';
import { buildLockTx, buildReleaseMilestoneTx, buildRefundTx, buildAdminResolveTx } from '../../src/services/escrow.service';
import { getTxInfo } from '../../src/services/blockchain.service';

describe('Chain Adapters Platform Infrastructure (Sprint 1)', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('ChainAdapterRegistry', () => {
    it('should register and resolve Cardano adapter', () => {
      const adapter = chainAdapterRegistry.getAdapter('cardano');
      expect(adapter).toBeInstanceOf(CardanoAdapter);
      expect(adapter.chainName).toBe('Cardano');
      expect(adapter.nativeAssetSymbol).toBe('ADA');
    });


    it('should fall back to Cardano if no chain is specified', () => {
      const adapter = chainAdapterRegistry.getAdapter();
      expect(adapter).toBeInstanceOf(CardanoAdapter);
    });

    it('should throw error for unsupported chains', () => {
      expect(() => chainAdapterRegistry.getAdapter('solana')).toThrowError('Unsupported chain adapter');
    });
  });

  describe('CardanoAdapter spending paths delegation', () => {
    const cardano = new CardanoAdapter();

    it('delegates lock transaction building', async () => {
      const result = await cardano.buildLockTx('INV-123', 5000000, 'addr_test1customer');
      expect(buildLockTx).toHaveBeenCalledWith('INV-123', 'addr_test1customer');
      expect(result).toEqual({ txCbor: 'lock-cbor', scriptAddress: 'script-addr' });
    });

    it('delegates release milestone transaction building', async () => {
      const result = await cardano.buildReleaseTx('INV-123', 1, 'addr_test1customer');
      expect(buildReleaseMilestoneTx).toHaveBeenCalledWith('INV-123', 'addr_test1customer');
      expect(result).toEqual({ txCbor: 'release-cbor' });
    });

    it('delegates refund building', async () => {
      const result = await cardano.buildRefundTx('INV-123', 'addr_test1customer');
      expect(buildRefundTx).toHaveBeenCalledWith('INV-123', 'addr_test1customer');
      expect(result).toEqual({ txCbor: 'refund-cbor' });
    });

    it('delegates admin resolution building', async () => {
      const result = await cardano.buildResolveTx('INV-123', 3000000, 2000000);
      expect(buildAdminResolveTx).toHaveBeenCalledWith(
        'INV-123',
        expect.any(String),
        undefined,
        undefined,
        3000000,
        2000000
      );
      expect(result).toEqual({ txCbor: 'resolve-cbor' });
    });

    it('delegates payment verification', async () => {
      vi.mocked(getTxInfo).mockResolvedValueOnce({
        txHash: 'hash',
        blockHeight: 100,
        blockHash: 'block',
        slot: 1000,
        confirmations: 5,
        outputAddresses: ['addr_test1merchant'],
        totalOutputLovelace: 5000000,
      });

      const result = await cardano.verifyOnChainPayment('hash', 'addr_test1merchant', 5000000);
      expect(getTxInfo).toHaveBeenCalledWith('hash');
      expect(result.status).toBe('amount-matched');
      expect(result.totalPaid).toBe(5000000);
    });
  });
});
