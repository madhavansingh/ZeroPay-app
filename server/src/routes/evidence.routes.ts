import { Router, Request, Response } from 'express';
import multer from 'multer';
import axios from 'axios';
import { requireAuth } from '../middleware/auth';
import { uploadRateLimit } from '../middleware/rateLimit';
import { Invoice } from '../models/Invoice';
import { Evidence } from '../models/Evidence';
import { env } from '../config/env';
import { logger } from '../config/logger';
import { circuitRegistry } from '../config/circuitBreaker';

const router = Router();
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB limit
});

// POST /api/v1/evidence/upload
router.post(
  '/upload',
  requireAuth,
  uploadRateLimit,
  upload.single('file'),
  async (req: Request, res: Response): Promise<void> => {
    try {
      const file = req.file;
      const { invoiceId } = req.body;

      if (!file) {
        res.status(400).json({ success: false, error: 'No file uploaded' });
        return;
      }

      if (!invoiceId) {
        res.status(400).json({ success: false, error: 'invoiceId is required' });
        return;
      }

      // Verify invoice exists and user has authorization (is customer or merchant)
      const invoice = await Invoice.findOne({ invoiceId });
      if (!invoice) {
        res.status(404).json({ success: false, error: 'Invoice not found' });
        return;
      }

      const isMerchant = invoice.merchantId.toString() === req.user._id.toString();
      const isCustomer = invoice.customerId?.toString() === req.user._id.toString();
      const isAdmin = req.user.role === 'admin';

      if (!isMerchant && !isCustomer && !isAdmin) {
        res.status(403).json({ success: false, error: 'Not authorized to upload evidence for this invoice' });
        return;
      }

      // Pin file to IPFS via Pinata
      const formData = new FormData();
      const fileBlob = new Blob([file.buffer], { type: file.mimetype });
      formData.append('file', fileBlob, file.originalname);

      const pinataMetadata = JSON.stringify({
        name: `evidence-${invoiceId}-${Date.now()}-${file.originalname}`,
        keyvalues: {
          invoiceId,
          uploaderId: req.user._id.toString(),
        },
      });
      formData.append('pinataMetadata', pinataMetadata);

      logger.info('[evidence] Pinning file to IPFS via Pinata', { invoiceId, filename: file.originalname });

      const breaker = circuitRegistry.getOrCreate('pinata');
      const ipfsHash = await breaker.execute(
        async () => {
          const pinataRes = await axios.post<{ IpfsHash: string }>(
            'https://api.pinata.cloud/pinning/pinFileToIPFS',
            formData,
            {
              headers: {
                Authorization: `Bearer ${env.PINATA_JWT}`,
              },
              maxBodyLength: Infinity,
              timeout: 30_000,
            }
          );
          return pinataRes.data.IpfsHash;
        },
        (err: any) => {
          logger.error('[evidence] Pinata upload breaker triggered or failed', { error: err.message });
          throw err;
        }
      );

      // Save evidence record in MongoDB
      const evidence = await Evidence.create({
        invoiceId,
        uploaderId: req.user._id,
        ipfsHash,
        fileName: file.originalname,
        mimeType: file.mimetype,
        fileSize: file.size,
      });

      res.status(201).json({
        success: true,
        data: {
          evidenceId: evidence._id,
          ipfsHash: evidence.ipfsHash,
          fileName: evidence.fileName,
          mimeType: evidence.mimeType,
          fileSize: evidence.fileSize,
          createdAt: evidence.createdAt,
        },
      });
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      logger.error('[evidence] Upload failed', { detail: msg });
      res.status(500).json({ success: false, error: 'Evidence upload failed', detail: msg });
    }
  }
);

export default router;
