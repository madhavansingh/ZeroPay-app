import { Router, Request, Response } from 'express';
import { getAdaInrRate } from '../services/price.service';

const router = Router();

// GET /api/v1/price/ada-inr — Public endpoint, no auth required
router.get('/ada-inr', async (_req: Request, res: Response): Promise<void> => {
  try {
    const rate = await getAdaInrRate();
    res.json({ success: true, data: rate });
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Price fetch failed';
    res.status(503).json({ success: false, error: message });
  }
});

export default router;
