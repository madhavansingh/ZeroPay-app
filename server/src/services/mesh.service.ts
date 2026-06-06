import 'dotenv/config';
import { MeshTxBuilder, BlockfrostProvider } from '@meshsdk/core';
import { env } from '../config/env';
import { Invoice } from '../models/Invoice';

const METADATA_KEY = 674; // CIP standard key for payment metadata
const MAX_METADATA_BYTES = 64;

function truncateTo64Bytes(str: string): string {
  const encoded = new TextEncoder().encode(str);
  if (encoded.length <= MAX_METADATA_BYTES) return str;
  return new TextDecoder().decode(encoded.slice(0, MAX_METADATA_BYTES));
}

export interface BuildTxResult {
  unsignedCbor: string;
  invoiceId: string;
  amountLovelace: number;
  paymentAddress: string;
}

/**
 * Build an unsigned transaction CBOR for a payment invoice.
 *
 * Design: backend NEVER holds a signing key. It only builds the transaction
 * structure and returns the unsigned CBOR. The wallet (CIP-30 via window.cardano)
 * signs client-side and submits to the network itself.
 *
 * MeshJS MeshTxBuilder approach:
 * - No wallet required to build — uses BlockfrostProvider as data fetcher only
 * - Returns raw CBOR that the CIP-30 wallet can sign with signTx()
 */
export async function buildPaymentTx(invoiceId: string, customerAddress: string): Promise<BuildTxResult> {
  const invoice = await Invoice.findOne({ invoiceId });
  if (!invoice) throw new Error('Invoice not found');
  if (invoice.status !== 'pending') {
    throw new Error(`Cannot build tx for invoice with status: ${invoice.status}`);
  }
  if (invoice.expiresAt < new Date()) {
    throw new Error('Invoice has expired');
  }

  const provider = new BlockfrostProvider(env.BLOCKFROST_PROJECT_ID);

  // Build CIP-674 metadata (all values ≤ 64 bytes enforced by Cardano protocol)
  const metadataValue = {
    app: truncateTo64Bytes('zeropay'),
    schema: truncateTo64Bytes('1'),
    inv: truncateTo64Bytes(invoice.invoiceId),
    mid: truncateTo64Bytes(invoice.merchantStringId),
  };

  const txBuilder = new MeshTxBuilder({ fetcher: provider, verbose: false });

  // Fetch customer UTxOs to select inputs from
  const utxos = await provider.fetchAddressUTxOs(customerAddress);
  if (!utxos || utxos.length === 0) {
    throw new Error('No UTxOs found for the customer address. Please ensure the wallet is funded.');
  }

  // Build the tx:
  // - Output: lovelace to merchant's payment address
  // - Metadata: CIP-674 key 674 with invoice info
  // - Change: set to customer's payment address so Mesh can balance outputs using Blockfrost UTXOs
  const unsignedCbor = await txBuilder
    .txOut(invoice.paymentAddress, [{ unit: 'lovelace', quantity: invoice.amountLovelace.toString() }])
    .changeAddress(customerAddress)
    .selectUtxosFrom(utxos)
    .metadataValue(METADATA_KEY, metadataValue)
    .complete();

  return {
    unsignedCbor,
    invoiceId: invoice.invoiceId,
    amountLovelace: invoice.amountLovelace,
    paymentAddress: invoice.paymentAddress,
  };
}
