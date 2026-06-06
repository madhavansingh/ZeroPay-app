import { Router, Request, Response } from 'express';
import { requireAuth } from '../middleware/auth';

const router = Router();

// GET /api/v1/wallet/balances
router.get('/balances', requireAuth, (req: Request, res: Response) => {
  res.json([
    {
      symbol: 'ADA',
      name: 'Cardano',
      balance_units: 54500000000, // 54,500 ADA
      fiat_value: 21800.0,
      change_percent_24h: 4.2,
      hex_color: '#0033AD'
    },
    {
      symbol: 'USDC',
      name: 'USD Coin',
      balance_units: 150000, // $1,500 USDC
      fiat_value: 1500.0,
      change_percent_24h: -0.1,
      hex_color: '#2775CA'
    },
    {
      symbol: 'INR',
      name: 'Indian Rupee',
      balance_units: 185000, // ₹1,850 INR
      fiat_value: 1850.0,
      change_percent_24h: 0.0,
      hex_color: '#22C55E'
    }
  ]);
});

// GET /api/v1/wallet/transactions
router.get('/transactions', requireAuth, (req: Request, res: Response) => {
  res.json([
    {
      txHash: '0xabc1230000000000000000000000000000000000000000000000000000000123',
      type: 'Received',
      assetSymbol: 'USDC',
      amount_units: 250000, // 2,500 USDC
      counterpartyAddress: 'addr_test1qrm9x2zsux7va6w892g38szjs7as5a92s2c67q5da0a5e8c1ab999',
      timestamp: new Date().toISOString(),
      status: 'Confirmed'
    },
    {
      txHash: '0xdef4560000000000000000000000000000000000000000000000000000000456',
      type: 'Sent',
      assetSymbol: 'ADA',
      amount_units: 500000000, // 500 ADA
      counterpartyAddress: 'addr_test1vrm9x2zsux7va6w892g38szjs7as5a92s2c67q5da0a5e8c1ab999',
      timestamp: new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString(),
      status: 'Confirmed'
    }
  ]);
});

// POST /api/v1/wallet/transfer
router.post('/transfer', requireAuth, (req: Request, res: Response) => {
  const { recipient, amount, symbol } = req.body;
  res.json({
    success: true,
    txHash: 'tx_' + Math.random().toString(36).substring(2, 15)
  });
});

export default router;
