import { Router, Request, Response } from 'express';
import { requireAuth } from '../middleware/auth';
import { AppWallet, BlockfrostProvider, MeshTxBuilder } from '@meshsdk/core';
import { env } from '../config/env';
import { getAdaInrRate } from '../services/price.service';
import { getWalletAddressBalance } from '../services/blockchain.service';
import { Merchant } from '../models/Merchant';
import { Transaction } from '../models/Transaction';
import { LedgerTransaction } from '../models/LedgerTransaction';
import { Invoice } from '../models/Invoice';
import { User } from '../models/User';
import { logger } from '../config/logger';

const router = Router();

// GET /api/v1/wallet/balances
router.get('/balances', requireAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const walletAddress = req.user.walletAddress;
    const { rate } = await getAdaInrRate();

    let adaLovelace = 0;
    let balanceList: Array<{ unit: string; quantity: string }> = [];

    if (walletAddress) {
      balanceList = await getWalletAddressBalance(walletAddress);
      const lovelaceEntry = balanceList.find((b) => b.unit === 'lovelace');
      if (lovelaceEntry) {
        adaLovelace = parseInt(lovelaceEntry.quantity, 10);
      }
    }

    // Compute USDC balance on-chain if present, otherwise default to 0
    let usdcUnits = 0;
    const usdcAsset = balanceList.find(
      (b) => b.unit.toLowerCase().includes('usdc') || b.unit === 'usdc'
    );
    if (usdcAsset) {
      usdcUnits = parseInt(usdcAsset.quantity, 10);
    }

    // Compute ledger-based INR balance (debits vs credits)
    // Starting balance for testing/demo purposes is ₹10,000 INR = 1,000,000 Paise
    let totalPaise = 1000000;
    const accounts = [`customer:${req.user._id}`];
    const merchant = await Merchant.findOne({ userId: req.user._id });
    if (merchant) {
      accounts.push(`merchant:${merchant._id}`);
    }

    const ledgerTransactions = await LedgerTransaction.find({
      'entries.accountId': { $in: accounts },
    });

    for (const lt of ledgerTransactions) {
      for (const entry of lt.entries) {
        if (entry.accountId === `customer:${req.user._id}`) {
          if (entry.type === 'credit') totalPaise += entry.amountPaise;
          else if (entry.type === 'debit') totalPaise -= entry.amountPaise;
        } else if (merchant && entry.accountId === `merchant:${merchant._id}`) {
          if (entry.type === 'credit') totalPaise += entry.amountPaise;
          else if (entry.type === 'debit') totalPaise -= entry.amountPaise;
        }
      }
    }

    res.json([
      {
        symbol: 'ADA',
        name: 'Cardano',
        balance_units: adaLovelace,
        fiat_value: (adaLovelace / 1_000_000) * rate,
        change_percent_24h: 0.0,
        hex_color: '#0033AD',
      },
      {
        symbol: 'USDC',
        name: 'USD Coin',
        balance_units: usdcUnits,
        fiat_value: usdcUnits / 100,
        change_percent_24h: 0.0,
        hex_color: '#2775CA',
      },
      {
        symbol: 'INR',
        name: 'Indian Rupee',
        balance_units: totalPaise,
        fiat_value: totalPaise / 100,
        change_percent_24h: 0.0,
        hex_color: '#22C55E',
      },
    ]);
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Balances fetch failed';
    res.status(500).json({ success: false, error: message });
  }
});

// GET /api/v1/wallet/transactions
router.get('/transactions', requireAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const merchant = await Merchant.findOne({ userId: req.user._id });
    const accounts = [`customer:${req.user._id}`];
    if (merchant) {
      accounts.push(`merchant:${merchant._id}`);
    }

    // Fetch invoices to resolve transaction references
    const invoices = await Invoice.find({
      $or: [
        { customerId: req.user._id },
        { merchantId: merchant ? merchant._id : null },
      ],
    });
    const invoiceIds = invoices.map((i) => i._id);

    const [mongoTransactions, ledgerTransactions] = await Promise.all([
      Transaction.find({ invoiceId: { $in: invoiceIds } })
        .populate({
          path: 'invoiceId',
          populate: { path: 'merchantId' }
        })
        .lean(),
      LedgerTransaction.find({
        'entries.accountId': { $in: accounts },
      }).lean(),
    ]);

    const formattedTxs: any[] = [];

    // Format blockchain transactions
    for (const tx of mongoTransactions) {
      const invoice = tx.invoiceId as any;
      if (!invoice) continue;

      const isMerchant = merchant && invoice.merchantId && invoice.merchantId._id.toString() === merchant._id.toString();
      const type = isMerchant ? 'Received' : 'Sent';
      const counterparty = isMerchant
        ? (invoice.escrowCustomerAddress || 'Customer')
        : (invoice.merchantId?.shopName || invoice.paymentAddress);

      let status = 'Confirmed';
      if (tx.status === 'submitted' || tx.status === 'confirming') {
        status = 'Pending';
      } else if (tx.status === 'failed') {
        status = 'Failed';
      }

      formattedTxs.push({
        txHash: tx.txHash,
        type,
        assetSymbol: 'ADA',
        amount_units: tx.amountLovelaceExpected,
        counterpartyAddress: counterparty,
        timestamp: tx.confirmedAt?.toISOString() || tx.createdAt.toISOString(),
        status,
      });
    }

    // Format ledger transactions
    for (const lt of ledgerTransactions) {
      const entry = lt.entries.find((e) => accounts.includes(e.accountId));
      if (!entry) continue;

      const type = entry.type === 'debit' ? 'Sent' : 'Received';
      const counterpartyEntry = lt.entries.find((e) => !accounts.includes(e.accountId));
      const counterpartyAddress = counterpartyEntry ? counterpartyEntry.accountId : 'Platform';

      formattedTxs.push({
        txHash: lt.ledgerTxId,
        type,
        assetSymbol: 'INR',
        amount_units: entry.amountPaise,
        counterpartyAddress,
        timestamp: lt.createdAt.toISOString(),
        status: 'Confirmed',
      });
    }

    // Sort by timestamp desc
    formattedTxs.sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime());

    res.json(formattedTxs);
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Transactions fetch failed';
    res.status(500).json({ success: false, error: message });
  }
});

// POST /api/v1/wallet/transfer
router.post('/transfer', requireAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const { recipient, amount, symbol, mnemonic } = req.body;

    if (!recipient) {
      res.status(400).json({ success: false, error: 'Recipient is required' });
      return;
    }
    if (!amount || amount <= 0) {
      res.status(400).json({ success: false, error: 'Amount must be positive' });
      return;
    }

    // On-chain ADA transfer
    if (symbol === 'ADA' && mnemonic) {
      const provider = new BlockfrostProvider(env.BLOCKFROST_PROJECT_ID);
      const wallet = new AppWallet({
        networkId: env.BLOCKFROST_NETWORK === 'mainnet' ? 1 : 0,
        fetcher: provider,
        submitter: provider,
        key: {
          type: 'mnemonic',
          words: typeof mnemonic === 'string' ? mnemonic.trim().split(/\s+/) : mnemonic,
        },
      });

      const txBuilder = new MeshTxBuilder({ fetcher: provider, verbose: false });
      const changeAddress = wallet.getPaymentAddress();
      const utxos = await provider.fetchAddressUTxOs(changeAddress);

      if (!utxos || utxos.length === 0) {
        res.status(400).json({ success: false, error: 'No UTxOs found in sender wallet' });
        return;
      }

      const unsignedCbor = await txBuilder
        .txOut(recipient, [{ unit: 'lovelace', quantity: amount.toString() }])
        .changeAddress(changeAddress)
        .selectUtxosFrom(utxos)
        .complete();

      const signedTx = await wallet.signTx(unsignedCbor);
      logger.info(`[CARDANO_TX_SIGNED] Escrow ID: N/A | Wallet Address: ${changeAddress} | Amount: ${amount} Lovelace | Network: Cardano | Transaction Hash: N/A`);

      const txHash = await wallet.submitTx(signedTx);
      logger.info(`[CARDANO_TX_SUBMITTED] Escrow ID: N/A | Wallet Address: ${changeAddress} | Amount: ${amount} Lovelace | Network: Cardano | Transaction Hash: ${txHash}`);

      res.json({
        success: true,
        txHash,
      });
      return;
    }

    // Local ledger INR/Paise transfer
    const recipientUser = await User.findOne({ walletAddress: recipient });

    const invoiceId = `transfer_${Date.now()}`;
    await LedgerTransaction.create({
      invoiceId,
      entries: [
        {
          accountId: `customer:${req.user._id}`,
          type: 'debit',
          amountLovelace: 0,
          amountPaise: amount,
        },
        {
          accountId: recipientUser ? `customer:${recipientUser._id}` : `wallet:${recipient}`,
          type: 'credit',
          amountLovelace: 0,
          amountPaise: amount,
        },
      ],
    });

    res.json({
      success: true,
      txHash: `LT-${invoiceId}`,
    });
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Transfer failed';
    res.status(400).json({ success: false, error: message });
  }
});

// POST /api/v1/wallet/sign
router.post('/sign', requireAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const { unsignedCbor, mnemonic } = req.body;
    if (!unsignedCbor) {
      res.status(400).json({ success: false, error: 'Missing unsignedCbor' });
      return;
    }
    if (!mnemonic) {
      res.status(400).json({ success: false, error: 'Missing mnemonic' });
      return;
    }

    const provider = new BlockfrostProvider(env.BLOCKFROST_PROJECT_ID);
    const wallet = new AppWallet({
      networkId: env.BLOCKFROST_NETWORK === 'mainnet' ? 1 : 0,
      fetcher: provider,
      submitter: provider,
      key: {
        type: 'mnemonic',
        words: typeof mnemonic === 'string' ? mnemonic.trim().split(/\s+/) : mnemonic,
      },
    });

    // Extract invoiceId and query details for clean structured logging
    let invoiceId = 'N/A';
    let amountStr = 'N/A';
    let network = 'Cardano';
    
    const cborMatch = unsignedCbor.match(/494e562d3230[0-9a-f]{26}/i);
    if (cborMatch) {
      try {
        const extractedId = Buffer.from(cborMatch[0], 'hex').toString('utf8');
        const dbInvoice = await Invoice.findOne({ invoiceId: extractedId });
        if (dbInvoice) {
          invoiceId = dbInvoice.invoiceId;
          amountStr = `${dbInvoice.amountLovelace} Lovelace`;
          network = dbInvoice.network || 'Cardano';
        }
      } catch (e) {
        // ignore
      }
    }

    const signedTx = await wallet.signTx(unsignedCbor);
    logger.info(`[CARDANO_TX_SIGNED] Escrow ID: ${invoiceId} | Wallet Address: ${wallet.getPaymentAddress()} | Amount: ${amountStr} | Network: ${network} | Transaction Hash: N/A`);

    const txHash = await wallet.submitTx(signedTx);
    logger.info(`[CARDANO_TX_SUBMITTED] Escrow ID: ${invoiceId} | Wallet Address: ${wallet.getPaymentAddress()} | Amount: ${amountStr} | Network: ${network} | Transaction Hash: ${txHash}`);

    res.json({
      success: true,
      data: {
        txHash,
      },
    });
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Signing failed';
    res.status(400).json({ success: false, error: message });
  }
});

export default router;
