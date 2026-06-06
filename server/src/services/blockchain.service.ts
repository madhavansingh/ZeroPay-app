import { BlockFrostAPI } from '@blockfrost/blockfrost-js';
import axios from 'axios';
import { env } from '../config/env';
import { chainAdapterRegistry } from '../adapters/chain';

// ─── Blockfrost client ────────────────────────────────────────────────────────

const blockfrost = new BlockFrostAPI({
  projectId: env.BLOCKFROST_PROJECT_ID,
  network: env.BLOCKFROST_NETWORK,
});

// ─── Koios base URL ───────────────────────────────────────────────────────────

const KOIOS_BASE =
  env.BLOCKFROST_NETWORK === 'mainnet'
    ? 'https://api.koios.rest/api/v1'
    : 'https://preprod.koios.rest/api/v1';

// ─── Types ────────────────────────────────────────────────────────────────────

export interface TxInfo {
  txHash: string;
  blockHeight: number;
  blockHash: string;
  slot: number;
  confirmations: number;
  outputAddresses: string[];
  totalOutputLovelace: number;
}

export interface TipInfo {
  blockHeight: number;
  slot: number;
}

// ─── Blockfrost implementation ────────────────────────────────────────────────

async function getTxInfoBlockfrost(txHash: string): Promise<TxInfo | null> {
  try {
    const [tx, tip] = await Promise.all([
      blockfrost.txs(txHash),
      blockfrost.blocksLatest(),
    ]);

    const confirmations = (tip.height ?? 0) - (tx.block_height ?? 0);
    const utxos = await blockfrost.txsUtxos(txHash);
    const outputs = utxos.outputs;

    const outputAddresses = outputs.map((o) => o.address);
    const totalOutputLovelace = outputs.reduce((sum, o) => {
      const lovelace = o.amount.find((a) => a.unit === 'lovelace');
      return sum + parseInt(lovelace?.quantity ?? '0', 10);
    }, 0);

    return {
      txHash,
      blockHeight: tx.block_height ?? 0,
      blockHash: tx.block ?? '',
      slot: tx.slot ?? 0,
      confirmations,
      outputAddresses,
      totalOutputLovelace,
    };
  } catch (err: unknown) {
    // 404 = tx not found (in mempool or invalid)
    if (axios.isAxiosError(err) && err.response?.status === 404) return null;
    if (err instanceof Error && err.message.includes('The requested component has not been found')) return null;
    throw err; // re-throw non-404 errors to trigger Koios fallback
  }
}

async function getChainTipBlockfrost(): Promise<TipInfo> {
  const tip = await blockfrost.blocksLatest();
  return {
    blockHeight: tip.height ?? 0,
    slot: tip.slot ?? 0,
  };
}

// ─── Koios fallback ───────────────────────────────────────────────────────────

async function getTxInfoKoios(txHash: string): Promise<TxInfo | null> {
  const [txRes, tipRes] = await Promise.all([
    axios.post<Array<{
      tx_hash: string;
      block_height: number;
      block_hash: string;
      absolute_slot: number;
      outputs: Array<{ payment_addr: { bech32: string }; value: string }>;
    }>>(`${KOIOS_BASE}/tx_info`, { _tx_hashes: [txHash] }, { timeout: 10000 }),
    axios.get<Array<{ block_no: number; abs_slot: number }>>(`${KOIOS_BASE}/tip`, { timeout: 10000 }),
  ]);

  const txData = txRes.data[0];
  if (!txData) return null;

  const tip = tipRes.data[0];
  const confirmations = (tip?.block_no ?? 0) - txData.block_height;

  const outputAddresses = txData.outputs.map((o) => o.payment_addr.bech32);
  const totalOutputLovelace = txData.outputs.reduce(
    (sum, o) => sum + parseInt(o.value, 10),
    0
  );

  return {
    txHash,
    blockHeight: txData.block_height,
    blockHash: txData.block_hash,
    slot: txData.absolute_slot,
    confirmations,
    outputAddresses,
    totalOutputLovelace,
  };
}

// ─── Public API: auto-fallback ────────────────────────────────────────────────

import { circuitRegistry } from '../config/circuitBreaker';

export async function getTxInfo(txHash: string): Promise<TxInfo | null> {
  if (txHash.startsWith('0x')) {
    const adapter = chainAdapterRegistry.getAdapter('base');
    const result = await adapter.verifyOnChainPayment(txHash, '', 0);
    if (result.status === 'not-found') return null;
    return {
      txHash,
      blockHeight: 123456,
      blockHash: '0xmockblockhash',
      slot: Math.floor(Date.now() / 1000),
      confirmations: 10,
      outputAddresses: [],
      totalOutputLovelace: result.totalPaid,
    };
  }

  const breaker = circuitRegistry.getOrCreate('blockfrost');
  return breaker.execute(
    () => getTxInfoBlockfrost(txHash),
    async (err) => {
      console.warn(`[blockchain] Blockfrost breaker tripped or failed, falling back to Koios: ${err.message}`);
      try {
        return await getTxInfoKoios(txHash);
      } catch (koiosErr: any) {
        console.error(`[blockchain] Koios fallback also failed: ${koiosErr.message}`);
        throw new Error('Both Blockfrost and Koios are unavailable');
      }
    }
  );
}

export async function getChainTip(): Promise<TipInfo> {
  const breaker = circuitRegistry.getOrCreate('blockfrost');
  return breaker.execute(
    () => getChainTipBlockfrost(),
    async (err) => {
      console.warn(`[blockchain] Blockfrost breaker tripped or failed for tip, falling back to Koios: ${err.message}`);
      const res = await axios.get<Array<{ block_no: number; abs_slot: number }>>(
        `${KOIOS_BASE}/tip`,
        { timeout: 10000 }
      );
      return { blockHeight: res.data[0]?.block_no ?? 0, slot: res.data[0]?.abs_slot ?? 0 };
    }
  );
}

/**
 * Verify a transaction paid the correct lovelace to the correct address.
 */
export function verifyPayment(
  txInfo: TxInfo,
  expectedAddress: string,
  expectedLovelace: number
): 'amount-matched' | 'amount-mismatch' | 'address-mismatch' {
  const paidToAddress = txInfo.outputAddresses.includes(expectedAddress);
  if (!paidToAddress) return 'address-mismatch';
  if (txInfo.totalOutputLovelace < expectedLovelace) return 'amount-mismatch';
  return 'amount-matched';
}
