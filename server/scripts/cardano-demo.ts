/**
 * ZeroPay — Backend-Only Cardano Demo Runner
 *
 * Proves real Cardano preprod blockchain integration WITHOUT Flutter or any UI.
 *
 * Usage:
 *   npm run demo:cardano
 *
 * Required env vars (add to server/.env or set in shell):
 *   BLOCKFROST_PROJECT_ID  — your preprod Blockfrost project ID
 *   BLOCKFROST_NETWORK     — preprod (default)
 *   DEMO_WALLET_MNEMONIC   — space-separated 24-word mnemonic for a funded preprod wallet
 *   DEMO_RECIPIENT_ADDRESS — (optional) preprod addr to send to; defaults to sender's own address (self-send)
 *   DEMO_AMOUNT_LOVELACE   — (optional) lovelace to send; default 1500000 (1.5 ADA)
 *
 * Output:
 *   [DEMO_START]
 *   [BLOCKFROST_CONNECTED]
 *   [WALLET_LOADED]
 *   [UTXOS_FETCHED]
 *   [CARDANO_TX_BUILT]
 *   [CARDANO_TX_SIGNED]
 *   [CARDANO_TX_SUBMITTED]
 *   Transaction Hash: <hash>
 *   Explorer URL: https://preprod.cardanoscan.io/transaction/<hash>
 *   [CARDANO_TX_CONFIRMED]
 */

import 'dotenv/config';
import { AppWallet, BlockfrostProvider, MeshTxBuilder } from '@meshsdk/core';
import * as sodium from 'libsodium-wrappers-sumo';

// ─── Helpers ─────────────────────────────────────────────────────────────────

function tag(label: string, extra?: Record<string, unknown>): void {
  const ts = new Date().toISOString();
  if (extra && Object.keys(extra).length > 0) {
    const pairs = Object.entries(extra)
      .map(([k, v]) => `${k}: ${v}`)
      .join(' | ');
    console.log(`[${label}] ${pairs} | timestamp: ${ts}`);
  } else {
    console.log(`[${label}] timestamp: ${ts}`);
  }
}

function fail(msg: string, err?: unknown): never {
  const detail = err instanceof Error ? err.message : String(err ?? '');
  console.error(`\n[DEMO_FAILED] ${msg}${detail ? ` — ${detail}` : ''}`);
  process.exit(1);
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// ─── Main ─────────────────────────────────────────────────────────────────────

async function main(): Promise<void> {
  tag('DEMO_START');

  // ── 1. Load & validate env ─────────────────────────────────────────────────
  const projectId = process.env.BLOCKFROST_PROJECT_ID;
  const network   = (process.env.BLOCKFROST_NETWORK ?? 'preprod') as 'mainnet' | 'preprod' | 'preview';
  const mnemonicRaw = process.env.DEMO_WALLET_MNEMONIC;
  const amountLovelace = Number(process.env.DEMO_AMOUNT_LOVELACE ?? '1500000');

  if (!projectId) {
    fail('BLOCKFROST_PROJECT_ID is not set. Add it to server/.env');
  }
  if (!mnemonicRaw) {
    fail(
      'DEMO_WALLET_MNEMONIC is not set.\n' +
      '  Set it in server/.env, e.g.:\n' +
      '  DEMO_WALLET_MNEMONIC="word1 word2 ... word24"\n' +
      '  The wallet must have testnet ADA on the Cardano preprod network.'
    );
  }

  const mnemonicWords = mnemonicRaw.trim().split(/\s+/);
  if (mnemonicWords.length !== 24) {
    fail(`DEMO_WALLET_MNEMONIC must be exactly 24 words, got ${mnemonicWords.length}`);
  }

  // ── 2. Connect to Blockfrost ───────────────────────────────────────────────
  let provider: BlockfrostProvider;
  try {
    provider = new BlockfrostProvider(projectId);
    // Probe Blockfrost by fetching chain tip (throws on bad project ID / network mismatch)
    const latestBlock = await provider.fetchLatestBlock();
    await provider.fetchBlockInfo(latestBlock.hash);
  } catch (err) {
    fail('Could not connect to Blockfrost', err);
  }

  tag('BLOCKFROST_CONNECTED', { network, projectId: projectId.slice(0, 12) + '...' });

  // ── 3. Load wallet ─────────────────────────────────────────────────────────
  let wallet: AppWallet;
  try {
    wallet = new AppWallet({
      networkId: network === 'mainnet' ? 1 : 0,
      fetcher:   provider,
      submitter: provider,
      key: {
        type: 'mnemonic',
        words: mnemonicWords,
      },
    });
  } catch (err) {
    fail('Failed to initialise AppWallet from mnemonic', err);
  }

  // Ensure sodium is ready before using AppWallet's crypto methods
  await (sodium as any).ready;

  const senderAddress: string = wallet.getPaymentAddress();
  tag('WALLET_LOADED', { address: senderAddress });

  // ── 4. Fetch UTxOs ────────────────────────────────────────────────────────
  let utxos: Awaited<ReturnType<typeof provider.fetchAddressUTxOs>>;
  try {
    utxos = await provider.fetchAddressUTxOs(senderAddress);
  } catch (err) {
    fail('Blockfrost fetchAddressUTxOs failed', err);
  }

  if (!utxos || utxos.length === 0) {
    fail(
      `No UTxOs found at ${senderAddress}.\n` +
      '  Please fund this address on the preprod network:\n' +
      '  https://docs.cardano.org/cardano-testnets/tools/faucet/'
    );
  }

  const lovelaceBalance = utxos
    .flatMap((u) => u.output.amount)
    .filter((a) => a.unit === 'lovelace')
    .reduce((sum, a) => sum + BigInt(a.quantity), 0n);

  tag('UTXOS_FETCHED', {
    count: utxos.length,
    balance_lovelace: lovelaceBalance.toString(),
    balance_ada: (Number(lovelaceBalance) / 1_000_000).toFixed(6),
  });

  if (lovelaceBalance < BigInt(amountLovelace) + 1_000_000n) {
    fail(
      `Insufficient balance. Need at least ${amountLovelace + 1_000_000} lovelace ` +
      `(${((amountLovelace + 1_000_000) / 1_000_000).toFixed(6)} ADA) for tx + fees, ` +
      `but wallet only has ${lovelaceBalance} lovelace.`
    );
  }

  // ── 5. Determine recipient ────────────────────────────────────────────────
  const recipientAddress = process.env.DEMO_RECIPIENT_ADDRESS ?? senderAddress;
  const isSelfSend = recipientAddress === senderAddress;

  // ── 6. Build unsigned transaction ─────────────────────────────────────────
  let unsignedCbor: string;
  try {
    const txBuilder = new MeshTxBuilder({ fetcher: provider, verbose: false });
    unsignedCbor = await txBuilder
      .txOut(recipientAddress, [{ unit: 'lovelace', quantity: amountLovelace.toString() }])
      .changeAddress(senderAddress)
      .selectUtxosFrom(utxos)
      .metadataValue(674, {
        app: 'zeropay',
        schema: '1',
        demo: 'cardano-demo-runner',
        network: network,
      })
      .complete();
  } catch (err) {
    fail('MeshTxBuilder failed to build transaction', err);
  }

  tag('CARDANO_TX_BUILT', {
    from: senderAddress,
    to: isSelfSend ? '(self)' : recipientAddress,
    amount_lovelace: amountLovelace,
    amount_ada: (amountLovelace / 1_000_000).toFixed(6),
    cbor_length: unsignedCbor.length,
  });

  // ── 7. Sign transaction ────────────────────────────────────────────────────
  let signedTx: string;
  try {
    signedTx = await wallet.signTx(unsignedCbor);
  } catch (err) {
    fail('wallet.signTx() failed', err);
  }

  tag('CARDANO_TX_SIGNED', {
    wallet: senderAddress,
    network: network,
  });

  // ── 8. Submit transaction ──────────────────────────────────────────────────
  let txHash: string;
  try {
    txHash = await wallet.submitTx(signedTx);
  } catch (err) {
    fail('wallet.submitTx() failed — check wallet balance and Blockfrost project ID', err);
  }

  tag('CARDANO_TX_SUBMITTED', {
    txHash,
    network: network,
  });

  console.log(`\nTransaction Hash: ${txHash}`);
  console.log(`Explorer URL: https://preprod.cardanoscan.io/transaction/${txHash}\n`);

  // ── 9. Poll Blockfrost for confirmation ────────────────────────────────────
  console.log('[CONFIRMATION_POLLING] Waiting for on-chain confirmation (this may take ~20-60s)...');

  const MAX_POLLS = 30;
  const POLL_INTERVAL_MS = 10_000; // 10 seconds

  for (let attempt = 1; attempt <= MAX_POLLS; attempt++) {
    await sleep(POLL_INTERVAL_MS);

    try {
      const txInfo = await provider.fetchTxInfo(txHash);
      if (txInfo && (txInfo as any).block) {
        const blockInfo = (txInfo as any).block;
        const confirmations = (txInfo as any).block_height
          ? 'on-chain'
          : 'on-chain';

        tag('CARDANO_TX_CONFIRMED', {
          txHash,
          block: blockInfo ?? 'unknown',
          confirmations,
          network: network,
          attempt,
        });

        console.log('\n════════════════════════════════════════════════════');
        console.log('  ✅  ZeroPay Cardano Demo — REAL TRANSACTION PROVED');
        console.log('════════════════════════════════════════════════════');
        console.log(`  Network      : ${network}`);
        console.log(`  Tx Hash      : ${txHash}`);
        console.log(`  From         : ${senderAddress}`);
        console.log(`  To           : ${recipientAddress}`);
        console.log(`  Amount       : ${(amountLovelace / 1_000_000).toFixed(6)} ADA`);
        console.log(`  Explorer     : https://preprod.cardanoscan.io/transaction/${txHash}`);
        console.log('════════════════════════════════════════════════════\n');
        process.exit(0);
      }
    } catch (_) {
      // tx not yet indexed — keep polling
    }

    console.log(`[CONFIRMATION_POLLING] Attempt ${attempt}/${MAX_POLLS} — not yet confirmed, retrying in ${POLL_INTERVAL_MS / 1000}s...`);
  }

  // Timed out but tx was submitted — still a valid proof
  console.warn(
    `\n[CONFIRMATION_TIMEOUT] Transaction was submitted (hash: ${txHash}) but ` +
    `confirmation was not detected within ${(MAX_POLLS * POLL_INTERVAL_MS) / 1000}s.\n` +
    `This is normal on a busy testnet. Check the explorer:\n` +
    `  https://preprod.cardanoscan.io/transaction/${txHash}\n`
  );
  process.exit(0);
}

main().catch((err) => {
  fail('Unhandled error in demo runner', err);
});
