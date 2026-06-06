import { Router, Request, Response } from 'express';
import { requireAuth } from '../middleware/auth';
import { DisputeVerdict } from '../models/DisputeVerdict';
import { Invoice } from '../models/Invoice';
import { User } from '../models/User';
import { Merchant } from '../models/Merchant';
import { JurorVote } from '../models/JurorVote';
import { Evidence } from '../models/Evidence';
import { Juror } from '../models/Juror';
import { submitJurorVote } from '../services/arbitration.service';
import { env } from '../config/env';

const router = Router();

// GET /api/v1/court/cases — Fetch all dispute cases formatted for client
router.get(
  '/cases',
  requireAuth,
  async (req: Request, res: Response): Promise<void> => {
    try {
      const verdicts = await DisputeVerdict.find().sort({ createdAt: -1 });
      const cases = [];

      for (const verdict of verdicts) {
        const invoice = await Invoice.findOne({ invoiceId: verdict.invoiceId });
        
        let plaintiffName = 'Alex Chen';
        let defendantName = 'Nexus Electronics Ltd.';
        let disputed_amount_units = 0;
        let assetSymbol = 'USDC';
        let title = 'Smart Contract Escrow Transfer Deliberation';

        if (invoice) {
          title = invoice.description || title;
          disputed_amount_units = invoice.amountLovelace || invoice.amountPaise || 0;
          assetSymbol = invoice.amountLovelace > 0 ? 'ADA' : 'USDC';

          if (invoice.customerId) {
            const customer = await User.findById(invoice.customerId);
            if (customer) {
              plaintiffName = customer.displayName || plaintiffName;
            }
          }

          const merchant = await Merchant.findById(invoice.merchantId);
          if (merchant) {
            defendantName = merchant.shopName || defendantName;
          }
        }

        // Map status
        let status = 'Deliberation';
        if (verdict.status === 'accepted' || verdict.status === 'executed') {
          status = 'Resolved';
        }

        // Populate jurors
        const jurors = [];
        if (verdict.assignedJurors && verdict.assignedJurors.length > 0) {
          const jurorUsers = await User.find({ _id: { $in: verdict.assignedJurors } });
          for (const jurorUser of jurorUsers) {
            const vote = await JurorVote.findOne({ disputeId: verdict.invoiceId, jurorId: jurorUser._id });
            jurors.push({
              id: jurorUser._id.toString(),
              name: jurorUser.displayName || `Juror #${jurorUser._id.toString().slice(-3)}`,
              status: vote ? 'Active' : 'Pending Vote',
              hasVoted: !!vote,
            });
          }
        }

        cases.push({
          caseId: verdict.invoiceId,
          title,
          disputed_amount_units,
          assetSymbol,
          plaintiffName,
          defendantName,
          status,
          filingDate: (verdict.createdAt || new Date()).toISOString(),
          consensusLeaningCustomer: verdict.customerSplitPercent || 50.0,
          jurors,
        });
      }

      res.json(cases);
    } catch (err: any) {
      res.status(500).json({ success: false, error: err.message });
    }
  }
);

// GET /api/v1/court/cases/:caseId — Fetch a single case by ID
router.get(
  '/cases/:caseId',
  requireAuth,
  async (req: Request, res: Response): Promise<void> => {
    try {
      const { caseId } = req.params;
      const verdict = await DisputeVerdict.findOne({ invoiceId: caseId });
      if (!verdict) {
        res.status(404).json({ success: false, error: 'Dispute case not found' });
        return;
      }

      const invoice = await Invoice.findOne({ invoiceId: verdict.invoiceId });
      let plaintiffName = 'Alex Chen';
      let defendantName = 'Nexus Electronics Ltd.';
      let disputed_amount_units = 0;
      let assetSymbol = 'USDC';
      let title = 'Smart Contract Escrow Transfer Deliberation';

      if (invoice) {
        title = invoice.description || title;
        disputed_amount_units = invoice.amountLovelace || invoice.amountPaise || 0;
        assetSymbol = invoice.amountLovelace > 0 ? 'ADA' : 'USDC';

        if (invoice.customerId) {
          const customer = await User.findById(invoice.customerId);
          if (customer) {
            plaintiffName = customer.displayName || plaintiffName;
          }
        }

        const merchant = await Merchant.findById(invoice.merchantId);
        if (merchant) {
          defendantName = merchant.shopName || defendantName;
        }
      }

      let status = 'Deliberation';
      if (verdict.status === 'accepted' || verdict.status === 'executed') {
        status = 'Resolved';
      }

      const jurors = [];
      if (verdict.assignedJurors && verdict.assignedJurors.length > 0) {
        const jurorUsers = await User.find({ _id: { $in: verdict.assignedJurors } });
        for (const jurorUser of jurorUsers) {
          const vote = await JurorVote.findOne({ disputeId: verdict.invoiceId, jurorId: jurorUser._id });
          jurors.push({
            id: jurorUser._id.toString(),
            name: jurorUser.displayName || `Juror #${jurorUser._id.toString().slice(-3)}`,
            status: vote ? 'Active' : 'Pending Vote',
            hasVoted: !!vote,
          });
        }
      }

      res.json({
        caseId: verdict.invoiceId,
        title,
        disputed_amount_units,
        assetSymbol,
        plaintiffName,
        defendantName,
        status,
        filingDate: (verdict.createdAt || new Date()).toISOString(),
        consensusLeaningCustomer: verdict.customerSplitPercent || 50.0,
        jurors,
      });
    } catch (err: any) {
      res.status(500).json({ success: false, error: err.message });
    }
  }
);

// POST /api/v1/court/evidence — Submit evidence file hash
router.post(
  '/evidence',
  requireAuth,
  async (req: Request, res: Response): Promise<void> => {
    try {
      const { case_id, evidence_hash } = req.body;
      if (!case_id || !evidence_hash) {
        res.status(400).json({ success: false, error: 'case_id and evidence_hash are required' });
        return;
      }

      const invoice = await Invoice.findOne({ invoiceId: case_id });
      if (!invoice) {
        res.status(404).json({ success: false, error: 'Invoice not found for this case' });
        return;
      }

      // Check if evidence already uploaded
      const existingEvidence = await Evidence.findOne({ ipfsHash: evidence_hash });
      if (existingEvidence) {
        res.status(400).json({ success: false, error: 'Evidence hash already submitted' });
        return;
      }

      const evidence = await Evidence.create({
        invoiceId: case_id,
        uploaderId: req.user._id,
        ipfsHash: evidence_hash,
        fileName: `evidence_${evidence_hash.slice(0, 6)}.pdf`,
        mimeType: 'application/pdf',
        fileSize: 1024 * 50, // Default 50 KB dummy size
      });

      res.status(201).json({
        success: true,
        data: evidence,
      });
    } catch (err: any) {
      res.status(500).json({ success: false, error: err.message });
    }
  }
);

// POST /api/v1/court/vote — Juror casting consensus vote
router.post(
  '/vote',
  requireAuth,
  async (req: Request, res: Response): Promise<void> => {
    try {
      const { case_id, support_plaintiff, reasoning } = req.body;
      if (!case_id || support_plaintiff === undefined) {
        res.status(400).json({ success: false, error: 'case_id and support_plaintiff are required' });
        return;
      }

      const verdict = await DisputeVerdict.findOne({ invoiceId: case_id });
      if (!verdict) {
        res.status(404).json({ success: false, error: 'Dispute verdict case not found' });
        return;
      }

      const activeUserId = req.user._id;

      // Check environment-aware juror assignment behavior
      const isAssigned = verdict.assignedJurors?.some((id) => id.toString() === activeUserId.toString());

      if (!isAssigned) {
        if (env.NODE_ENV !== 'production' && env.DEV_AUTH_ENABLED === true) {
          // Dev Mode: Auto-assign user as a juror
          verdict.assignedJurors = verdict.assignedJurors || [];
          verdict.assignedJurors.push(activeUserId);
          await verdict.save();

          // Ensure Juror record exists in dev mode so reputation changes can be updated
          const existingJuror = await Juror.findOne({ userId: activeUserId });
          if (!existingJuror) {
            await Juror.create({
              userId: activeUserId,
              status: 'idle',
              stakedReputation: 100,
              accuracyScore: 90,
              disputesResolvedCount: 0,
            });
          }
          console.log(`[Court Routes] Auto-assigned active developer ${activeUserId} as juror for dispute ${case_id}`);
        } else {
          // Production Mode: Throw 403 Forbidden
          res.status(403).json({
            success: false,
            error: 'Juror is not assigned to arbitrate this dispute',
          });
          return;
        }
      }

      // Map support_plaintiff true/false to customer/merchant split percentages
      const recommendedCustomerSplitPct = support_plaintiff ? 100 : 0;
      const recommendedMerchantSplitPct = support_plaintiff ? 0 : 100;

      await submitJurorVote({
        invoiceId: case_id,
        jurorUserId: activeUserId.toString(),
        recommendedMerchantSplitPct,
        recommendedCustomerSplitPct,
        reasoning: reasoning || `Vote cast in favor of ${support_plaintiff ? 'plaintiff' : 'defendant'}`,
      });

      res.json({
        success: true,
        message: 'Vote submitted successfully',
      });
    } catch (err: any) {
      res.status(500).json({ success: false, error: err.message });
    }
  }
);

export default router;
