import { describe, it, expect, vi } from 'vitest';
import { findActiveEscrowUtxo, buildReleaseMilestoneTx, buildRaiseDisputeTx, buildAdminResolveTx } from '../../src/services/escrow.service';
import { Invoice } from '../../src/models/Invoice';

// Mock env variables
vi.mock('../../src/config/env', () => ({
  env: {
    BLOCKFROST_PROJECT_ID: 'mock_project_id',
    ESCROW_PLATFORM_FEE_LOVELACE: 100000,
    ESCROW_ADMIN_ADDRESS: 'addr_test1qrr2cldldladmin',
    ESCROW_TREASURY_ADDRESS: 'addr_test1qrr2cldldltreasury',
  },
}));

// Mock Mesh SDK (classes defined inside the hoisted vi.mock block)
vi.mock('@meshsdk/core', () => {
  class MockBlockfrostProvider {
    fetchAddressUTxOs(address: string) {
      if (address === 'addr_test1wpzzpjrf856y94vvssyr8fjekf7zhk0g0vffltcz0lpkyhcq9h3z9') {
        return Promise.resolve([
          {
            input: {
              txHash: '1111111111111111111111111111111111111111111111111111111111111111',
              outputIndex: 0,
            },
            output: {
              address: 'addr_test1wpzzpjrf856y94vvssyr8fjekf7zhk0g0vffltcz0lpkyhcq9h3z9',
              amount: [{ unit: 'lovelace', quantity: '5100000' }],
              plutusData: 'datum_cbor_hex_test',
            },
          },
          {
            input: {
              txHash: '3333333333333333333333333333333333333333333333333333333333333333',
              outputIndex: 0,
            },
            output: {
              address: 'addr_test1wpzzpjrf856y94vvssyr8fjekf7zhk0g0vffltcz0lpkyhcq9h3z9',
              amount: [{ unit: 'lovelace', quantity: '5100000' }],
              plutusData: 'datum_cbor_hex_dispute',
            },
          },
        ]);
      }
      return Promise.resolve([
        {
          input: {
            txHash: '2222222222222222222222222222222222222222222222222222222222222222',
            outputIndex: 0,
          },
          output: {
            address,
            amount: [{ unit: 'lovelace', quantity: '20000000' }],
          },
        },
      ]);
    }
  }

  class MockMeshTxBuilder {
    constructor() {}
    txIn() { return this; }
    txInInlineDatumPresent() { return this; }
    txInRedeemerValue() { return this; }
    spendingPlutusScriptV3() { return this; }
    txInScript() { return this; }
    txOut() { return this; }
    txOutInlineDatumValue() { return this; }
    changeAddress() { return this; }
    selectUtxosFrom() { return this; }
    requiredSignerHash() { return this; }
    metadataValue() { return this; }
    complete() { return Promise.resolve('mock_unsigned_cbor'); }
  }

  return {
    MeshTxBuilder: MockMeshTxBuilder,
    BlockfrostProvider: MockBlockfrostProvider,
    deserializeAddress: vi.fn().mockImplementation((address) => ({
      pubKeyHash: 'mock_pkh_' + address.slice(-8),
      scriptHash: undefined,
    })),
    deserializeDatum: vi.fn().mockImplementation((cbor) => {
      if (cbor === 'datum_cbor_hex_test') {
        return {
          alternative: 0,
          fields: [
            'merchant_pkh',
            'customer_pkh',
            'admin_pkh',
            Buffer.from('INV-20260524-TEST', 'utf8').toString('hex'), // fields[3]
            100000n, // platform fee
            'treasury_pkh',
            [], // totalAmount
            [], // releasedAmount
            0n, // milestoneIndex
            1n, // totalMilestones
            { alternative: 0, fields: [] }, // state Alt
            100000n, // expirySlot
            100000n, // grace slots
            'agreement',
            'metadata',
            1n, // version
          ],
        };
      }
      if (cbor === 'datum_cbor_hex_dispute') {
        return {
          alternative: 0,
          fields: [
            'merchant_pkh',
            'customer_pkh',
            'admin_pkh',
            Buffer.from('INV-20260524-DISPUTED', 'utf8').toString('hex'), // fields[3]
            100000n, // platform fee
            'treasury_pkh',
            [], // totalAmount
            [], // releasedAmount
            0n, // milestoneIndex
            1n, // totalMilestones
            { alternative: 2, fields: [] }, // state Alt (2 = Disputed)
            100000n, // expirySlot
            100000n, // grace slots
            'agreement',
            'metadata',
            1n, // version
          ],
        };
      }
      throw new Error('Unknown datum cbor');
    }),
  };
});

// Mock Mongoose Invoice model
vi.mock('../../src/models/Invoice', () => {
  return {
    Invoice: {
      findOne: vi.fn().mockImplementation(({ invoiceId }) => {
        if (invoiceId === 'INV-20260524-TEST') {
          return {
            invoiceId: 'INV-20260524-TEST',
            paymentAddress: 'addr_test1qr5w75a9t94x9k6y3qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq',
            amountLovelace: 5000000,
            escrowState: 'Locked',
            milestoneIndex: 0,
            totalMilestones: 1,
            milestones: [
              { title: 'Milestone 1', amountLovelace: 5000000, status: 'pending' },
            ],
            agreementHash: 'agreement_cid',
            metadataHash: 'metadata_cid',
            contractVersion: 1,
            escrowCustomerAddress: 'addr_test1qrr2cldldlcustomer',
          };
        }
        if (invoiceId === 'INV-20260524-DISPUTED') {
          return {
            invoiceId: 'INV-20260524-DISPUTED',
            paymentAddress: 'addr_test1qr5w75a9t94x9k6y3qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq',
            amountLovelace: 5000000,
            escrowState: 'Disputed',
            milestoneIndex: 0,
            totalMilestones: 1,
            milestones: [
              { title: 'Milestone 1', amountLovelace: 5000000, status: 'pending' },
            ],
            agreementHash: 'agreement_cid',
            metadataHash: 'metadata_cid',
            contractVersion: 1,
            escrowCustomerAddress: 'addr_test1qrr2cldldlcustomer',
          };
        }
        return null;
      }),
    },
    ESCROW_SCRIPT_ADDRESS: 'addr_test1wpzzpjrf856y94vvssyr8fjekf7zhk0g0vffltcz0lpkyhcq9h3z9',
    isValidTransition: (from: any, to: any) => true,
  };
});

describe('Escrow Service - UTxO Auto-Discovery & Builders', () => {
  it('should find active escrow UTxO dynamically', async () => {
    const utxo = await findActiveEscrowUtxo('INV-20260524-TEST');
    expect(utxo).not.toBeNull();
    expect(utxo?.txHash).toBe('1111111111111111111111111111111111111111111111111111111111111111');
    expect(utxo?.txIndex).toBe(0);
    expect(utxo?.amountLovelace).toBe(5100000);
  });

  it('should build release milestone transaction dynamically finding UTxO', async () => {
    const result = await buildReleaseMilestoneTx(
      'INV-20260524-TEST',
      'addr_test1qrr2cldldlcustomer'
    );
    expect(result.unsignedCbor).toBe('mock_unsigned_cbor');
    expect(result.invoiceId).toBe('INV-20260524-TEST');
  });

  it('should build raise dispute transaction dynamically finding UTxO', async () => {
    const result = await buildRaiseDisputeTx(
      'INV-20260524-TEST',
      'addr_test1qrr2cldldlcustomer'
    );
    expect(result.unsignedCbor).toBe('mock_unsigned_cbor');
    expect(result.invoiceId).toBe('INV-20260524-TEST');
  });

  it('should build admin resolve transaction dynamically finding UTxO', async () => {
    const result = await buildAdminResolveTx(
      'INV-20260524-DISPUTED',
      'addr_test1qrr2cldldladmin',
      undefined,
      undefined,
      3000000,
      2000000,
      'addr_test1qrr2cldldlcustomer'
    );
    expect(result.unsignedCbor).toBe('mock_unsigned_cbor');
    expect(result.invoiceId).toBe('INV-20260524-DISPUTED');
  });
});
