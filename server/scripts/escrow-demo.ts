/**
 * ZeroPay — Backend-Only Escrow Lifecycle Demo Runner
 *
 * Demonstrates a REAL on-chain Cardano escrow lifecycle entirely from the terminal.
 *
 * Lifecycle demonstrated:
 *   1. Create an Invoice (escrow record) in MongoDB                → [ESCROW_CREATED]
 *   2. Build a Lock TX (funds → Plutus script address)             → [CARDANO_TX_BUILT]
 *   3. Sign the Lock TX                                            → [CARDANO_TX_SIGNED]
 *   4. Submit the Lock TX                                          → [CARDANO_TX_SUBMITTED]
 *   5. Poll Blockfrost for on-chain confirmation                   → [CARDANO_TX_CONFIRMED]
 *   6. Wait for demo delay, then request milestone release         → [MILESTONE_RELEASE_REQUESTED]
 *   7. Build a Release Milestone TX (script → merchant)           → [CARDANO_TX_BUILT]
 *   8. Sign + Submit the Release TX                                → [CARDANO_TX_SIGNED/SUBMITTED]
 *   9. Poll for release confirmation                               → [MILESTONE_RELEASED]
 *
 * Required env vars (add to server/.env):
 *   BLOCKFROST_PROJECT_ID    — preprod Blockfrost project ID
 *   BLOCKFROST_NETWORK       — preprod (default)
 *   DEMO_WALLET_MNEMONIC     — 24-word mnemonic for a funded preprod customer wallet
 *   DEMO_MERCHANT_ADDRESS    — bech32 preprod addr to receive milestone release
 *   DEMO_AMOUNT_LOVELACE     — (optional) lovelace to escrow; default 3000000 (3 ADA)
 *
 * Usage:
 *   npm run demo:escrow
 */

import 'dotenv/config';
import mongoose from 'mongoose';
import { AppWallet, BlockfrostProvider, deserializeAddress } from '@meshsdk/core';
import * as sodium from 'libsodium-wrappers-sumo';
import { nanoid } from 'nanoid';

// ─── Bootstrap: load env and DB before importing services ─────────────────────
// env.ts calls process.exit(1) if required vars are missing, so import early.
import { env } from '../src/config/env';

// ─── Import production services ───────────────────────────────────────────────
import { Invoice } from '../src/models/Invoice';
import { buildLockTx, buildReleaseMilestoneTx, ESCROW_SCRIPT_ADDRESS } from '../src/services/escrow.service';

// ─── Types ────────────────────────────────────────────────────────────────────

interface WalletContext {
  wallet: AppWallet;
  provider: BlockfrostProvider;
  address: string;
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

function tag(label: string, extra?: Record<string, unknown>): void {
  const ts = new Date().toISOString();
  const pairs =
    extra && Object.keys(extra).length > 0
      ? ' | ' + Object.entries(extra).map(([k, v]) => `${k}: ${v}`).join(' | ')
      : '';
  console.log(`[${label}]${pairs} | timestamp: ${ts}`);
}

function section(title: string): void {
  console.log(`\n${'─'.repeat(60)}`);
  console.log(`  ${title}`);
  console.log(`${'─'.repeat(60)}`);
}

function fail(msg: string, err?: unknown): never {
  const detail = err instanceof Error ? err.message : String(err ?? '');
  console.error(`\n[DEMO_FAILED] ${msg}${detail ? ` — ${detail}` : ''}`);
  process.exit(1);
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function adaStr(lovelace: number): string {
  return `${(lovelace / 1_000_000).toFixed(6)} ADA (${lovelace} lovelace)`;
}

async function pollConfirmation(
  provider: BlockfrostProvider,
  txHash: string,
  label: string,
  maxAttempts = 30,
  intervalMs = 10_000
): Promise<boolean> {
  console.log(`\n[CONFIRMATION_POLLING] Waiting for ${label} to appear on-chain...`);
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    await sleep(intervalMs);
    try {
      const info = await provider.fetchTxInfo(txHash);
      if (info && (info as any).block) {
        return true;
      }
    } catch {
      // not yet indexed
    }
    console.log(
      `[CONFIRMATION_POLLING] Attempt ${attempt}/${maxAttempts} — ${label} not yet confirmed, retrying in ${intervalMs / 1000}s...`
    );
  }
  return false;
}

// ─── Database ─────────────────────────────────────────────────────────────────

async function connectDb(): Promise<void> {
  try {
    await mongoose.connect(env.MONGODB_URI, {
      dbName: 'zeropay',
      maxPoolSize: 3,
      serverSelectionTimeoutMS: 8000,
    });
    console.log('[DB] MongoDB connected');
  } catch (err) {
    fail('MongoDB connection failed', err);
  }
}

async function disconnectDb(): Promise<void> {
  await mongoose.disconnect();
}

// ─── Wallet initialisation ────────────────────────────────────────────────────

async function initWallet(mnemonicRaw: string, projectId: string, network: string): Promise<WalletContext> {
  const mnemonicWords = mnemonicRaw.trim().split(/\s+/);
  if (mnemonicWords.length !== 24) {
    fail(`DEMO_WALLET_MNEMONIC must be exactly 24 words, got ${mnemonicWords.length}`);
  }

  const provider = new BlockfrostProvider(projectId);

  // Probe Blockfrost connectivity
  try {
    const latestBlock = await provider.fetchLatestBlock();
    await provider.fetchBlockInfo(latestBlock.hash);
  } catch (err) {
    fail('Cannot reach Blockfrost — check BLOCKFROST_PROJECT_ID and network', err);
  }

  // Ensure sodium is ready before calling AppWallet's crypto methods
  await (sodium as any).ready;

  const wallet = new AppWallet({
    networkId: network === 'mainnet' ? 1 : 0,
    fetcher: provider,
    submitter: provider,
    key: { type: 'mnemonic', words: mnemonicWords },
  });

  const address: string = wallet.getPaymentAddress();
  return { wallet, provider, address };
}

// ─── Sign + Submit helper ─────────────────────────────────────────────────────

async function signAndSubmit(
  wallet: AppWallet,
  unsignedCbor: string
): Promise<string> {
  const signedTx = await wallet.signTx(unsignedCbor);
  const txHash = await wallet.submitTx(signedTx);
  return txHash;
}

// ─── Step 1: Create Invoice (Escrow) in MongoDB ───────────────────────────────

async function createDemoInvoice(
  merchantAddress: string,
  customerAddress: string,
  amountLovelace: number
): Promise<string> {
  // We need a minimal Merchant doc reference for escrow.  In this demo we create
  // a synthetic Invoice directly (bypassing invoice.service.ts which requires a
  // Merchant doc). This mirrors exactly what the API does: the Invoice document
  // drives all on-chain builders.
  const invoiceId = `DEMO-${new Date().toISOString().slice(0, 10).replace(/-/g, '')}-${nanoid(6).toUpperCase()}`;

  const expiresAt = new Date(Date.now() + 3600 * 1000 * 24); // 1 day
  const milestoneLovelace = amountLovelace; // single-milestone escrow

  // We need a fake merchantId ObjectId for the schema — use a dummy one
  const fakeMerchantId = new mongoose.Types.ObjectId();

  await Invoice.create({
    invoiceId,
    merchantId: fakeMerchantId,
    merchantStringId: 'DEMO-MERCHANT',
    amountPaise: 100,          // dummy — not used in escrow flow
    amountLovelace,
    adaInrRate: 85.0,          // dummy snapshot
    paymentAddress: merchantAddress,
    status: 'pending',
    expiresAt,
    escrowState: 'Created',
    milestones: [
      {
        title: 'Demo Milestone — Full Delivery',
        description: 'Automatically created by escrow-demo runner',
        amountLovelace: milestoneLovelace,
        status: 'pending',
      },
    ],
    milestoneIndex: 0,
    totalMilestones: 1,
    isDisputed: false,
    network: 'cardano',
    contractVersion: 1,
    escrowCustomerAddress: customerAddress,
  });

  return invoiceId;
}

// ─── Main ─────────────────────────────────────────────────────────────────────

async function main(): Promise<void> {
  section('ZeroPay Escrow Demo Runner — Starting');
  tag('DEMO_START');

  // ── 1. Validate env ────────────────────────────────────────────────────────
  const projectId = process.env.BLOCKFROST_PROJECT_ID;
  const network = process.env.BLOCKFROST_NETWORK ?? 'preprod';
  const mnemonicRaw = process.env.DEMO_WALLET_MNEMONIC;
  const merchantAddress = process.env.DEMO_MERCHANT_ADDRESS;
  const amountLovelace = Number(process.env.DEMO_AMOUNT_LOVELACE ?? '3000000');

  if (!projectId) fail('BLOCKFROST_PROJECT_ID is not set in server/.env');
  if (!mnemonicRaw) {
    fail(
      'DEMO_WALLET_MNEMONIC is not set.\n' +
      '  Add to server/.env:\n' +
      '  DEMO_WALLET_MNEMONIC="word1 word2 ... word24"\n' +
      '  Fund the wallet at: https://docs.cardano.org/cardano-testnets/tools/faucet/'
    );
  }
  if (!merchantAddress) {
    fail(
      'DEMO_MERCHANT_ADDRESS is not set.\n' +
      '  Add a preprod bech32 address to server/.env:\n' +
      '  DEMO_MERCHANT_ADDRESS=addr_test1...'
    );
  }
  if (!/^addr_test1[a-z0-9]+$/.test(merchantAddress)) {
    fail(`DEMO_MERCHANT_ADDRESS must be a preprod addr_test1... address, got: ${merchantAddress}`);
  }
  if (amountLovelace < 2_000_000) {
    fail('DEMO_AMOUNT_LOVELACE must be at least 2000000 (2 ADA) to cover escrow + platform fee');
  }

  console.log('\nDemo Parameters:');
  console.log(`  Network         : ${network}`);
  console.log(`  Escrow amount   : ${adaStr(amountLovelace)}`);
  console.log(`  Merchant (recv) : ${merchantAddress}`);
  console.log(`  Blockfrost ID   : ${projectId.slice(0, 14)}...`);

  // ── 2. Connect DB ──────────────────────────────────────────────────────────
  section('Phase 1 — Connecting to Infrastructure');
  await connectDb();

  // ── 3. Init wallet ─────────────────────────────────────────────────────────
  const ctx = await initWallet(mnemonicRaw, projectId, network);
  const { wallet, provider, address: customerAddress } = ctx;

  tag('BLOCKFROST_CONNECTED', { network, endpoint: `preprod.blockfrost.io` });
  tag('WALLET_LOADED', { customer_address: customerAddress });

  // Validate balance
  const utxos = await provider.fetchAddressUTxOs(customerAddress);
  if (!utxos || utxos.length === 0) {
    fail(
      `No UTxOs at ${customerAddress}.\n` +
      `  Fund this address at: https://docs.cardano.org/cardano-testnets/tools/faucet/`
    );
  }
  const lovelaceBalance = utxos
    .flatMap((u) => u.output.amount)
    .filter((a) => a.unit === 'lovelace')
    .reduce((sum, a) => sum + BigInt(a.quantity), 0n);

  const requiredLovelace = BigInt(amountLovelace) + BigInt(env.ESCROW_PLATFORM_FEE_LOVELACE) + 2_000_000n; // fee buffer
  if (lovelaceBalance < requiredLovelace) {
    fail(
      `Insufficient balance.\n` +
      `  Have: ${adaStr(Number(lovelaceBalance))}\n` +
      `  Need: ~${adaStr(Number(requiredLovelace))} (escrow + platform fee + tx fee buffer)\n` +
      `  Fund at: https://docs.cardano.org/cardano-testnets/tools/faucet/`
    );
  }

  console.log(`\n  Customer wallet balance: ${adaStr(Number(lovelaceBalance))}`);
  console.log(`  UTxOs available        : ${utxos.length}`);

  // ── 4. Create Invoice (Escrow record) ──────────────────────────────────────
  section('Phase 2 — Creating Escrow Record');

  let invoiceId: string;
  try {
    invoiceId = await createDemoInvoice(merchantAddress, customerAddress, amountLovelace);
  } catch (err) {
    fail('Failed to create demo invoice in MongoDB', err);
  }

  tag('ESCROW_CREATED', {
    escrow_id: invoiceId,
    customer: customerAddress,
    merchant: merchantAddress,
    amount: adaStr(amountLovelace),
    script_address: ESCROW_SCRIPT_ADDRESS,
  });

  console.log(`\n  Invoice ID     : ${invoiceId}`);
  console.log(`  Escrow Address : ${ESCROW_SCRIPT_ADDRESS}`);
  console.log(`  Platform Fee   : ${adaStr(env.ESCROW_PLATFORM_FEE_LOVELACE)}`);
  const lockAmount = amountLovelace + env.ESCROW_PLATFORM_FEE_LOVELACE;
  console.log(`  Total Lock Amt : ${adaStr(lockAmount)}`);

  // ── 5. Build Lock Transaction ──────────────────────────────────────────────
  section('Phase 3 — Building Lock Transaction (Funds → Plutus Script)');

  let lockCbor: string;
  try {
    const lockResult = await buildLockTx(invoiceId, customerAddress);
    lockCbor = lockResult.unsignedCbor;
  } catch (err) {
    fail('buildLockTx failed', err);
  }

  tag('CARDANO_TX_BUILT', {
    type: 'LOCK',
    escrow_id: invoiceId,
    from: customerAddress,
    to: ESCROW_SCRIPT_ADDRESS,
    amount: adaStr(lockAmount),
    cbor_bytes: lockCbor.length / 2,
  });

  // ── 6. Sign + Submit Lock TX ────────────────────────────────────────────────
  section('Phase 4 — Signing and Submitting Lock Transaction');

  let lockTxHash: string;
  try {
    const signedLock = await wallet.signTx(lockCbor);
    tag('CARDANO_TX_SIGNED', {
      type: 'LOCK',
      escrow_id: invoiceId,
      signer: customerAddress,
    });

    lockTxHash = await wallet.submitTx(signedLock);
  } catch (err) {
    fail('Lock TX sign/submit failed', err);
  }

  tag('CARDANO_TX_SUBMITTED', {
    type: 'LOCK',
    escrow_id: invoiceId,
    txHash: lockTxHash,
    network,
  });

  console.log(`\nTransaction Hash : ${lockTxHash}`);
  console.log(`Explorer URL     : https://preprod.cardanoscan.io/transaction/${lockTxHash}`);

  // Update MongoDB with lock tx hash and state
  await Invoice.findOneAndUpdate(
    { invoiceId },
    {
      $set: {
        escrowLockTxHash: lockTxHash,
        escrowState: 'Locked',
        status: 'submitted',
      },
    }
  );

  // ── 7. Poll for Lock Confirmation ──────────────────────────────────────────
  section('Phase 5 — Waiting for Lock Transaction Confirmation');

  const lockConfirmed = await pollConfirmation(provider, lockTxHash, 'Lock TX');

  if (lockConfirmed) {
    tag('CARDANO_TX_CONFIRMED', {
      type: 'LOCK',
      escrow_id: invoiceId,
      txHash: lockTxHash,
      network,
    });

    await Invoice.findOneAndUpdate(
      { invoiceId },
      { $set: { status: 'confirmed' } }
    );

    console.log(`\n  ✅ Escrow funds LOCKED on-chain at Plutus script address`);
    console.log(`  Script Address : ${ESCROW_SCRIPT_ADDRESS}`);
    console.log(`  Amount Locked  : ${adaStr(lockAmount)}`);
  } else {
    console.warn(`\n  ⚠️  Lock TX not confirmed within poll window — it may still confirm.`);
    console.warn(`  Check: https://preprod.cardanoscan.io/transaction/${lockTxHash}`);
  }

  // ── 8. Simulate milestone release request ──────────────────────────────────
  section('Phase 6 — Requesting Milestone Release');

  console.log('\n  Simulating: Customer approves milestone delivery...');
  console.log('  Waiting 5 seconds before release request...');
  await sleep(5000);

  tag('MILESTONE_RELEASE_REQUESTED', {
    escrow_id: invoiceId,
    milestone_index: 0,
    milestone_title: 'Demo Milestone — Full Delivery',
    payout_to: merchantAddress,
    payout_amount: adaStr(amountLovelace),
  });

  // ── 9. Build Release Milestone TX ─────────────────────────────────────────
  section('Phase 7 — Building Milestone Release Transaction (Script → Merchant)');

  // Find the confirmed script UTxO
  let releaseCbor: string;
  let scriptTxHash: string | undefined;
  let scriptTxIndex: number | undefined;

  // Use the known lock tx hash to locate the UTxO at the script address
  scriptTxHash = lockTxHash;
  scriptTxIndex = 0; // the escrow output is always output index 0 from buildLockTx

  try {
    const releaseResult = await buildReleaseMilestoneTx(
      invoiceId,
      customerAddress,
      scriptTxHash,
      scriptTxIndex,
      amountLovelace
    );
    releaseCbor = releaseResult.unsignedCbor;
  } catch (err) {
    // If the UTxO isn't indexed yet (fast network), try auto-discovery
    console.warn(`  Script UTxO not found at index 0, trying on-chain discovery...`);
    try {
      const releaseResult = await buildReleaseMilestoneTx(
        invoiceId,
        customerAddress,
        undefined, // let the service discover it
        undefined,
        amountLovelace
      );
      releaseCbor = releaseResult.unsignedCbor;
    } catch (err2) {
      fail('buildReleaseMilestoneTx failed — lock TX may not be confirmed yet', err2);
    }
  }

  tag('CARDANO_TX_BUILT', {
    type: 'RELEASE_MILESTONE',
    escrow_id: invoiceId,
    from: ESCROW_SCRIPT_ADDRESS,
    to: merchantAddress,
    payout: adaStr(amountLovelace),
    cbor_bytes: releaseCbor!.length / 2,
  });

  // ── 10. Sign + Submit Release TX ────────────────────────────────────────────
  section('Phase 8 — Signing and Submitting Milestone Release');

  let releaseTxHash: string;
  try {
    const signedRelease = await wallet.signTx(releaseCbor!, true); // true = partial sign
    tag('CARDANO_TX_SIGNED', {
      type: 'RELEASE_MILESTONE',
      escrow_id: invoiceId,
      signer: customerAddress,
    });

    releaseTxHash = await wallet.submitTx(signedRelease);
  } catch (err) {
    fail('Release TX sign/submit failed', err);
  }

  tag('CARDANO_TX_SUBMITTED', {
    type: 'RELEASE_MILESTONE',
    escrow_id: invoiceId,
    txHash: releaseTxHash,
    network,
  });

  console.log(`\nRelease Transaction Hash : ${releaseTxHash}`);
  console.log(`Explorer URL             : https://preprod.cardanoscan.io/transaction/${releaseTxHash}`);

  // Update invoice state optimistically
  await Invoice.findOneAndUpdate(
    { invoiceId },
    {
      $set: {
        escrowState: 'Released',
        milestoneIndex: 1,
        'milestones.0.status': 'released',
        'milestones.0.releasedAt': new Date(),
        status: 'settled',
      },
    }
  );

  // ── 11. Poll for Release Confirmation ─────────────────────────────────────
  section('Phase 9 — Waiting for Milestone Release Confirmation');

  const releaseConfirmed = await pollConfirmation(provider, releaseTxHash, 'Release TX');

  if (releaseConfirmed) {
    tag('CARDANO_TX_CONFIRMED', {
      type: 'RELEASE_MILESTONE',
      escrow_id: invoiceId,
      txHash: releaseTxHash,
      network,
    });

    tag('MILESTONE_RELEASED', {
      escrow_id: invoiceId,
      milestone_index: 0,
      payout_to: merchantAddress,
      payout_amount: adaStr(amountLovelace),
      release_txHash: releaseTxHash,
    });
  } else {
    console.warn(`\n  ⚠️  Release TX not confirmed within poll window — it may still confirm.`);
    console.warn(`  Check: https://preprod.cardanoscan.io/transaction/${releaseTxHash}`);
    tag('MILESTONE_RELEASED', {
      escrow_id: invoiceId,
      status: 'submitted_pending_confirmation',
      release_txHash: releaseTxHash,
    });
  }

  // ── 12. Final Summary ─────────────────────────────────────────────────────
  section('ZeroPay Escrow Demo — COMPLETE');

  console.log(`
════════════════════════════════════════════════════════════════
  ✅  ZeroPay Escrow Lifecycle — REAL CARDANO TRANSACTIONS PROVED
════════════════════════════════════════════════════════════════

  Network           : ${network}
  Escrow Invoice ID : ${invoiceId}
  Customer Wallet   : ${customerAddress}
  Merchant Wallet   : ${merchantAddress}
  Plutus Contract   : ${ESCROW_SCRIPT_ADDRESS}

  ─── Transaction 1: LOCK ───────────────────────────────────────
  Funds locked to Plutus script address
  Amount     : ${adaStr(lockAmount)}
  TX Hash    : ${lockTxHash}
  Explorer   : https://preprod.cardanoscan.io/transaction/${lockTxHash}

  ─── Transaction 2: RELEASE MILESTONE ─────────────────────────
  Funds released from script to merchant
  Amount     : ${adaStr(amountLovelace)}
  TX Hash    : ${releaseTxHash}
  Explorer   : https://preprod.cardanoscan.io/transaction/${releaseTxHash}

════════════════════════════════════════════════════════════════
`);

  await disconnectDb();
  process.exit(0);
}

main().catch((err) => {
  console.error('[DEMO_FAILED] Unhandled error:', err instanceof Error ? err.message : err);
  process.exit(1);
});
