import { GoogleGenAI } from '@google/genai';
import { z } from 'zod';
import { env } from '../config/env';
import { Invoice } from '../models/Invoice';
import { Evidence } from '../models/Evidence';
import { getFirebaseDatabase } from '../config/firebase-admin';
import { logger } from '../config/logger';
import { AIAuditLog } from '../models/AIAuditLog';
import { ProjectPlan } from '../models/ProjectPlan';

export {
  PROMPT_VERSIONS,
  MilestoneSuggestion,
  DisputeSummary,
  EscrowExplanation,
  AnomalyReport,
  InvoiceDraft,
  MerchantInsight,
  PricingSuggestion,
  milestonesResponseSchema,
  disputeSummaryResponseSchema,
  projectPlanResponseSchema,
  githubAuditResponseSchema,
  GitHubAuditResponse,
} from './ai/ai.schemas';

import {
  PROMPT_VERSIONS,
  MilestoneSuggestion,
  DisputeSummary,
  EscrowExplanation,
  AnomalyReport,
  InvoiceDraft,
  MerchantInsight,
  PricingSuggestion,
  milestonesResponseSchema,
  disputeSummaryResponseSchema,
  projectPlanResponseSchema,
  githubAuditResponseSchema,
  GitHubAuditResponse,
} from './ai/ai.schemas';

// Instantiate the SDK only if not in mock mode to prevent initialization errors
const isMockMode = env.GEMINI_API_KEY.startsWith('mock-');
const ai = !isMockMode ? new GoogleGenAI({ apiKey: env.GEMINI_API_KEY }) : null;



// ─── Gemini API call wrapper with retry strategy ──────────────────────────────

async function generateContentWithRetry(
  prompt: string,
  responseSchema: any,
  maxAttempts: number = 3,
  modelName: string = 'gemini-2.0-flash'
): Promise<{ text: string; latencyMs: number }> {
  let attempt = 0;
  let delay = 1000;

  while (attempt < maxAttempts) {
    const startTime = Date.now();
    try {
      attempt++;
      if (isMockMode || !ai) {
        throw new Error('Gemini API is in mock/unconfigured mode');
      }

      const response = await ai.models.generateContent({
        model: modelName,
        contents: prompt,
        config: {
          responseMimeType: 'application/json',
          responseSchema: responseSchema,
        },
      });

      const latencyMs = Date.now() - startTime;
      if (!response.text) {
        throw new Error('Gemini returned an empty response');
      }
      return { text: response.text, latencyMs };
    } catch (err: any) {
      if (attempt >= maxAttempts) {
        logger.error(`[AI Service] Gemini call failed permanently after ${attempt} attempts.`, { error: err.message });
        throw err;
      }
      logger.warn(`[AI Service] Attempt ${attempt} failed: ${err.message}. Retrying in ${delay}ms...`);
      await new Promise((resolve) => setTimeout(resolve, delay));
      delay *= 2; // exponential backoff
    }
  }
  throw new Error('Gemini call exceeded max retries');
}

// ─── Core Services ────────────────────────────────────────────────────────────

/**
 * Generate structural milestones suggestion based on description and total amount.
 */
export async function generateMilestones(
  description: string,
  totalAmountPaise: number,
  actorId: string = 'system',
  requestId?: string
): Promise<MilestoneSuggestion[]> {
  const startTime = Date.now();
  const promptTemplate = `[Version: ${PROMPT_VERSIONS.GENERATE_MILESTONES}] You are a professional freelance project manager. Split the contract description into 2 to 5 logical milestones.
The total amount of all milestones combined MUST equal exactly {{totalAmount}} paise.
Contract Description: "{{description}}"
Ensure the sum of all 'amountPaise' equals {{totalAmount}} exactly.`;

  const prompt = promptTemplate
    .replace(/\{\{totalAmount\}\}/g, String(totalAmountPaise))
    .replace('{{description}}', description);

  const responseSchema = {
    type: 'OBJECT',
    properties: {
      milestones: {
        type: 'ARRAY',
        items: {
          type: 'OBJECT',
          properties: {
            title: { type: 'STRING', description: 'Brief description of the milestone deliverable' },
            amountPaise: { type: 'INTEGER', description: 'Amount allocated to this milestone in paise' },
          },
          required: ['title', 'amountPaise'],
        },
      },
    },
    required: ['milestones'],
  };

  const inputData = { description, totalAmountPaise, promptVersion: PROMPT_VERSIONS.GENERATE_MILESTONES };

  if (isMockMode) {
    const half = Math.floor(totalAmountPaise / 2);
    const mockOutput = [
      { title: 'Milestone 1: Design and Scaffolding', amountPaise: half },
      { title: 'Milestone 2: Delivery & Final Codebase Handover', amountPaise: totalAmountPaise - half },
    ];

    // Log mock execution in AIAuditLog
    await AIAuditLog.create({
      timestamp: new Date(),
      action: 'generate-milestones',
      actorId,
      requestId,
      promptTemplate,
      inputData,
      rawResponse: JSON.stringify({ milestones: mockOutput }),
      parsedResponse: { milestones: mockOutput },
      confidenceScore: 100,
      latencyMs: Date.now() - startTime,
      status: 'success',
    });

    return mockOutput;
  }

  try {
    const { text, latencyMs } = await generateContentWithRetry(prompt, responseSchema);
    const rawParsed = JSON.parse(text);

    // 1. Zod response schema validation
    const parsed = milestonesResponseSchema.safeParse(rawParsed);
    if (!parsed.success) {
      logger.error('[AI Service] Milestones response validation failed', { detail: JSON.stringify(parsed.error.flatten()) });
      throw new Error(`Zod validation failure: ${JSON.stringify(parsed.error.flatten())}`);
    }

    const milestones = parsed.data.milestones;

    // 2. Business logic sanity check & normalization (ensure exact total amount match)
    const sum = milestones.reduce((s, m) => s + m.amountPaise, 0);
    let confidenceScore = 100;
    if (sum !== totalAmountPaise) {
      confidenceScore = 75; // reduced confidence if normalized
      logger.warn('[AI Service] Milestones sum mismatch — normalizing last milestone', { sum, expected: totalAmountPaise });
      const diff = totalAmountPaise - sum;
      if (milestones.length > 0) {
        milestones[milestones.length - 1].amountPaise += diff;
      }
    }

    // Save success audit log
    await AIAuditLog.create({
      timestamp: new Date(),
      action: 'generate-milestones',
      actorId,
      requestId,
      promptTemplate,
      inputData,
      rawResponse: text,
      parsedResponse: { milestones },
      confidenceScore,
      latencyMs,
      status: 'success',
    });

    return milestones;
  } catch (err: any) {
    const latencyMs = Date.now() - startTime;
    // Dynamic fallback: Split total amount into 3 logical milestones based on description keywords
    const isWebOrFrontend = /website|frontend|storefront|page|ui|checkout|responsive/i.test(description);
    const m1 = Math.round(totalAmountPaise * 0.25);
    const m2 = Math.round(totalAmountPaise * 0.50);
    const m3 = totalAmountPaise - m1 - m2;

    const dynamicMilestones = isWebOrFrontend 
      ? [
          { title: 'UI Design & Mockup Review', amountPaise: m1 },
          { title: 'Frontend Components Development', amountPaise: m2 },
          { title: 'Deployment, Metrics & Final Handover', amountPaise: m3 },
        ]
      : [
          { title: 'Requirements Drafting & Setup', amountPaise: m1 },
          { title: 'Core Logic & Backend Integration', amountPaise: m2 },
          { title: 'Final System Audit & Handover', amountPaise: m3 },
        ];

    // Save failure audit log with the generated fallback milestones for tracking
    await AIAuditLog.create({
      timestamp: new Date(),
      action: 'generate-milestones',
      actorId,
      requestId,
      promptTemplate,
      inputData,
      validationErrors: err.message,
      parsedResponse: { milestones: dynamicMilestones },
      latencyMs,
      status: 'failure',
    });

    return dynamicMilestones;
  }
}

/**
 * Compile chat logs and IPFS evidence into a structured dispute brief.
 */
export async function summarizeDispute(
  invoiceId: string,
  actorId: string = 'system',
  requestId?: string
): Promise<DisputeSummary> {
  const startTime = Date.now();
  const invoice = await Invoice.findOne({ invoiceId });
  const evidenceList = await Evidence.find({ invoiceId });

  if (!invoice) throw new Error('Invoice not found');

  let chatText = 'No chat messages found.';
  if (invoice.chatRoomId) {
    try {
      const db = getFirebaseDatabase();
      const snapshot = await db.ref(`/chatrooms/${invoice.chatRoomId}/messages`).get();
      if (snapshot.exists()) {
        const messages: Record<string, any> = snapshot.val();
        chatText = Object.values(messages)
          .map((m) => `[${new Date(m.timestamp).toISOString()}] ${m.senderId}: ${JSON.stringify(m.payload || m.text || '')}`)
          .join('\n');
      }
    } catch (e: any) {
      logger.warn('[AI Service] Failed to fetch chat logs for dispute summary:', { error: e.message });
    }
  }

  const evidenceText = evidenceList.map((e) => `- File: ${e.fileName} (IPFS: ${e.ipfsHash}, Type: ${e.mimeType})`).join('\n');
  const inputData = { invoiceId, hasEvidence: evidenceList.length > 0, promptVersion: PROMPT_VERSIONS.SUMMARIZE_DISPUTE };

  const promptTemplate = `[Version: ${PROMPT_VERSIONS.SUMMARIZE_DISPUTE}] Analyze this dispute for Invoice {{invoiceId}}.
Total Amount: {{totalAmount}} Paise.
Description: "{{description}}"

--- CHAT LOGS ---
{{chatText}}

--- ATTACHED EVIDENCE ---
{{evidenceText}}

Decide a fair split percentage between merchant and customer. The sum of recommendedSplitMerchantPercent and recommendedSplitCustomerPercent must be exactly 100. Provide structured arbitration output.`;

  const prompt = promptTemplate
    .replace('{{invoiceId}}', invoiceId)
    .replace('{{totalAmount}}', String(invoice.amountPaise))
    .replace('{{description}}', invoice.description || '')
    .replace('{{chatText}}', chatText)
    .replace('{{evidenceText}}', evidenceText || 'No files attached');

  const responseSchema = {
    type: 'OBJECT',
    properties: {
      summary: { type: 'STRING', description: 'Overview of the dispute context' },
      keyClaims: { type: 'ARRAY', items: { type: 'STRING' }, description: 'Core arguments raised by each party' },
      recommendedSplitMerchantPercent: { type: 'INTEGER', description: 'Suggested percentage of funds to pay the merchant (0-100)' },
      recommendedSplitCustomerPercent: { type: 'INTEGER', description: 'Suggested percentage of funds to refund the customer (0-100)' },
      reasoning: { type: 'STRING', description: 'Detailed reasoning behind the recommended split decision' },
    },
    required: ['summary', 'keyClaims', 'recommendedSplitMerchantPercent', 'recommendedSplitCustomerPercent', 'reasoning'],
  };

  if (isMockMode) {
    const mockOutput: DisputeSummary = {
      summary: `Dispute summary for Invoice ${invoiceId} based on mock analysis. Dispute raised due to delivery delays.`,
      keyClaims: ['Merchant claims work is complete.', 'Customer claims work is incomplete.'],
      recommendedSplitMerchantPercent: 50,
      recommendedSplitCustomerPercent: 50,
      reasoning: 'Compromise recommended due to lack of distinct proof of completion.',
    };

    // Log mock execution
    await AIAuditLog.create({
      timestamp: new Date(),
      action: 'summarize-dispute',
      invoiceId,
      actorId,
      requestId,
      promptTemplate,
      inputData,
      rawResponse: JSON.stringify(mockOutput),
      parsedResponse: mockOutput,
      confidenceScore: 90,
      latencyMs: Date.now() - startTime,
      status: 'success',
    });

    return mockOutput;
  }

  try {
    const { text, latencyMs } = await generateContentWithRetry(prompt, responseSchema);
    const rawParsed = JSON.parse(text);

    // 1. Zod response schema validation
    const parsed = disputeSummaryResponseSchema.safeParse(rawParsed);
    if (!parsed.success) {
      logger.error('[AI Service] Dispute summary response validation failed', { detail: JSON.stringify(parsed.error.flatten()) });
      throw new Error(`Zod validation failure: ${JSON.stringify(parsed.error.flatten())}`);
    }

    const brief = parsed.data;

    // 2. Business logic validation (percentages must sum to 100)
    let confidenceScore = 95;
    const totalSplit = brief.recommendedSplitMerchantPercent + brief.recommendedSplitCustomerPercent;
    if (totalSplit !== 100) {
      confidenceScore = 60; // low confidence
      logger.warn('[AI Service] Recommended split percentages do not equal 100. Normalizing split.', {
        invoiceId,
        merchantPercent: brief.recommendedSplitMerchantPercent,
        customerPercent: brief.recommendedSplitCustomerPercent,
      });
      brief.recommendedSplitCustomerPercent = 100 - brief.recommendedSplitMerchantPercent;
    }

    // Save success audit log
    await AIAuditLog.create({
      timestamp: new Date(),
      action: 'summarize-dispute',
      invoiceId,
      actorId,
      requestId,
      promptTemplate,
      inputData,
      rawResponse: text,
      parsedResponse: brief,
      confidenceScore,
      latencyMs,
      status: 'success',
    });

    return brief;
  } catch (err: any) {
    const latencyMs = Date.now() - startTime;
    logger.error('[AI Service] Failed to summarize dispute, executing fallback.', { error: err.message });

    // Save failure audit log
    await AIAuditLog.create({
      timestamp: new Date(),
      action: 'summarize-dispute',
      invoiceId,
      actorId,
      requestId,
      promptTemplate,
      inputData,
      validationErrors: err.message,
      latencyMs,
      status: 'failure',
    });

    // Fallback: 100% split to customer
    return {
      summary: `Unable to compile AI dispute summary: ${err.message}`,
      keyClaims: ['Dispute raised by one of the parties.'],
      recommendedSplitMerchantPercent: 0,
      recommendedSplitCustomerPercent: 100,
      reasoning: 'Default fallback recommendation: refund 100% of funds to the customer.',
    };
  }
}

/**
 * Score transaction anomaly risk.
 */
export async function detectTransactionAnomaly(
  merchantAddress: string,
  customerAddress: string,
  amountLovelace: number,
  actorId: string = 'system',
  requestId?: string
): Promise<AnomalyReport> {
  const startTime = Date.now();
  const amountAda = amountLovelace / 1_000_000;
  logger.info('[ai] Scanning for transaction anomalies', { amountAda });

  const promptTemplate = `[Version: ${PROMPT_VERSIONS.DETECT_ANOMALY}] Rule-based anomaly validation engine for address check.`;
  const inputData = { merchantAddress, customerAddress, amountLovelace };

  // Advanced deterministic risk checking
  const factors: string[] = [];
  let score = 5;

  if (amountAda > 20000) {
    score += 40;
    factors.push('Extremely large ADA transaction amount');
  } else if (amountAda > 5000) {
    score += 20;
    factors.push('Large ADA transaction amount');
  }

  if (merchantAddress === customerAddress) {
    score += 50;
    factors.push('Merchant and Customer addresses are identical (Self-dealing)');
  }

  const report: AnomalyReport = {
    isAnomaly: score >= 50,
    score,
    factors,
  };

  // Log to AIAuditLog for parity in tracking
  await AIAuditLog.create({
    timestamp: new Date(),
    action: 'detect-anomaly',
    actorId,
    requestId,
    promptTemplate,
    inputData,
    rawResponse: JSON.stringify(report),
    parsedResponse: report,
    confidenceScore: 100,
    latencyMs: Date.now() - startTime,
    status: 'success',
  });

  return report;
}

/**
 * Explain the current escrow contract status in plain English.
 */
export async function explainEscrowStatus(invoiceId: string): Promise<EscrowExplanation> {
  const invoice = await Invoice.findOne({ invoiceId });
  if (!invoice) throw new Error('Invoice not found');

  const state = invoice.escrowState;

  const mapping: Record<string, EscrowExplanation> = {
    None: {
      headline: 'Invoice Generated',
      details: 'The invoice has been created but funds have not been locked into the escrow smart contract yet.',
      nextActionRequiredBy: 'buyer',
      plainEnglishStatus: 'Awaiting Lock',
    },
    Created: {
      headline: 'Contract Setup',
      details: 'The contract has been initialized. Awaiting customer deposit.',
      nextActionRequiredBy: 'buyer',
      plainEnglishStatus: 'Awaiting Lock',
    },
    Locked: {
      headline: 'Funds Secured',
      details: 'Funds are securely held in the Cardano smart contract. Work can safely begin. The merchant can request release upon milestone completion.',
      nextActionRequiredBy: 'seller',
      plainEnglishStatus: 'Work In Progress',
    },
    PartiallyReleased: {
      headline: 'Milestones in Progress',
      details: `Active milestone: ${invoice.milestoneIndex + 1} of ${invoice.totalMilestones}. Previous milestones have been successfully paid out.`,
      nextActionRequiredBy: 'seller',
      plainEnglishStatus: 'Progressive Release',
    },
    Released: {
      headline: 'Contract Completed',
      details: 'All funds have been successfully released to the merchant wallet. This contract is closed.',
      nextActionRequiredBy: 'none',
      plainEnglishStatus: 'Settled',
    },
    Refunded: {
      headline: 'Funds Refunded',
      details: 'Funds have been returned to the customer wallet. This contract is closed.',
      nextActionRequiredBy: 'none',
      plainEnglishStatus: 'Refunded',
    },
    Disputed: {
      headline: 'Contract Frozen (Dispute)',
      details: 'A dispute has been raised. Escrow funds are locked from spending by either party pending admin resolution.',
      nextActionRequiredBy: 'admin',
      plainEnglishStatus: 'Under Review',
    },
    Resolved: {
      headline: 'Dispute Resolved',
      details: 'The dispute was adjudicated by the platform admin, and remaining funds have been split and paid out.',
      nextActionRequiredBy: 'none',
      plainEnglishStatus: 'Resolved',
    },
  };

  return mapping[state] || {
    headline: 'Status Unknown',
    details: 'Status of this escrow contract is currently being fetched or synced.',
    nextActionRequiredBy: 'none',
    plainEnglishStatus: 'Syncing',
  };
}

// ─── Phase 3: Advanced AI Commerce Workflows ──────────────────────────────────



const invoiceDraftResponseSchema = z.object({
  lineItems: z.array(
    z.object({
      title: z.string(),
      pricePaise: z.number().int().positive(),
    })
  ),
  suggestedPrice: z.number().int().positive(),
  professionalTitle: z.string(),
  termsText: z.string(),
  estimatedCompletionDays: z.number().int().positive(),
});

const merchantInsightResponseSchema = z.object({
  revenueTrendNarrative: z.string(),
  topCategories: z.array(z.string()),
  pricingSuggestions: z.array(z.string()),
  peakHours: z.string(),
  retentionSignals: z.string(),
});

const pricingSuggestionResponseSchema = z.object({
  suggestedMinLovelace: z.number().int().positive(),
  suggestedMaxLovelace: z.number().int().positive(),
  benchmarkContext: z.string(),
  rationale: z.string(),
});

/**
 * Generate invoice draft details based on merchant description, category and price preference
 */
export async function generateInvoiceDraft(
  description: string,
  category: string,
  actorId: string = 'system',
  requestId?: string
): Promise<InvoiceDraft> {
  const startTime = Date.now();
  const promptTemplate = `You are a professional invoice drafting assistant. Given a category: "{{category}}" and description of work: "{{description}}", generate a detailed invoice proposal draft. Use standard Indian commerce pricing models.`;
  const prompt = promptTemplate.replace('{{category}}', category).replace('{{description}}', description);

  const responseSchema = {
    type: 'OBJECT',
    properties: {
      lineItems: {
        type: 'ARRAY',
        items: {
          type: 'OBJECT',
          properties: {
            title: { type: 'STRING' },
            pricePaise: { type: 'INTEGER' },
          },
          required: ['title', 'pricePaise'],
        },
      },
      suggestedPrice: { type: 'INTEGER' },
      professionalTitle: { type: 'STRING' },
      termsText: { type: 'STRING' },
      estimatedCompletionDays: { type: 'INTEGER' },
    },
    required: ['lineItems', 'suggestedPrice', 'professionalTitle', 'termsText', 'estimatedCompletionDays'],
  };

  const inputData = { description, category };

  if (isMockMode) {
    const mockOutput: InvoiceDraft = {
      lineItems: [
        { title: 'Project Consultation & Requirements Drafting', pricePaise: 500000 },
        { title: 'Full Design Mockups and Wireframe Handover', pricePaise: 1500000 },
      ],
      suggestedPrice: 2000000,
      professionalTitle: `${category.charAt(0).toUpperCase() + category.slice(1)} Consulting Services`,
      termsText: 'Payment locked in ZeroPay escrow. 100% payout released on completion of milestones.',
      estimatedCompletionDays: 14,
    };

    await AIAuditLog.create({
      timestamp: new Date(),
      action: 'generate-invoice-draft',
      actorId,
      requestId,
      promptTemplate,
      inputData,
      rawResponse: JSON.stringify(mockOutput),
      parsedResponse: mockOutput,
      confidenceScore: 95,
      latencyMs: Date.now() - startTime,
      status: 'success',
    });

    return mockOutput;
  }

  try {
    const { text, latencyMs } = await generateContentWithRetry(prompt, responseSchema);
    const rawParsed = JSON.parse(text);

    const parsed = invoiceDraftResponseSchema.safeParse(rawParsed);
    if (!parsed.success) {
      throw new Error(`Zod validation failure: ${JSON.stringify(parsed.error.flatten())}`);
    }

    const draft = parsed.data;

    await AIAuditLog.create({
      timestamp: new Date(),
      action: 'generate-invoice-draft',
      actorId,
      requestId,
      promptTemplate,
      inputData,
      rawResponse: text,
      parsedResponse: draft,
      confidenceScore: 90,
      latencyMs,
      status: 'success',
    });

    return draft;
  } catch (err: any) {
    const latencyMs = Date.now() - startTime;
    logger.error('[AI Service] Failed to generate invoice draft, returning safe fallback.', { error: err.message });

    await AIAuditLog.create({
      timestamp: new Date(),
      action: 'generate-invoice-draft',
      actorId,
      requestId,
      promptTemplate,
      inputData,
      validationErrors: err.message,
      latencyMs,
      status: 'failure',
    });

    return {
      lineItems: [{ title: 'Service Delivery', pricePaise: 1000000 }],
      suggestedPrice: 1000000,
      professionalTitle: 'Consulting Services',
      termsText: 'Payment locked in ZeroPay escrow.',
      estimatedCompletionDays: 7,
    };
  }
}

/**
 * Generate business analytics narrative and strategies for a merchant
 */
export async function generateMerchantInsight(
  merchantMongoId: string,
  windowDays: number = 30,
  actorId: string = 'system',
  requestId?: string
): Promise<MerchantInsight> {
  const startTime = Date.now();
  const promptTemplate = `Generate detailed business and pricing intelligence strategies for Merchant ID: {{merchantMongoId}} over the last {{windowDays}} days. Use modern marketing psychology principles.`;
  const prompt = promptTemplate.replace('{{merchantMongoId}}', merchantMongoId).replace('{{windowDays}}', String(windowDays));

  const responseSchema = {
    type: 'OBJECT',
    properties: {
      revenueTrendNarrative: { type: 'STRING' },
      topCategories: { type: 'ARRAY', items: { type: 'STRING' } },
      pricingSuggestions: { type: 'ARRAY', items: { type: 'STRING' } },
      peakHours: { type: 'STRING' },
      retentionSignals: { type: 'STRING' },
    },
    required: ['revenueTrendNarrative', 'topCategories', 'pricingSuggestions', 'peakHours', 'retentionSignals'],
  };

  const inputData = { merchantMongoId, windowDays };

  if (isMockMode) {
    const mockOutput: MerchantInsight = {
      revenueTrendNarrative: 'Revenue has maintained a robust upward trend, showing an increase in escrow volume with high customer satisfaction scores.',
      topCategories: ['Web Development', 'UIUX Design Consultancy', 'API Integrations'],
      pricingSuggestions: [
        'Bundle wireframing and initial consulting services to capture higher margin early commitments.',
        'Offer a 5% discount for payments locked fully on Cardano escrow with multiple milestones.',
      ],
      peakHours: 'Tuesdays and Thursdays, 14:00 - 18:00 IST',
      retentionSignals: 'Excellent progressive release milestone metrics with low dispute rates point to strong customer trust and repeat purchasing.',
    };

    await AIAuditLog.create({
      timestamp: new Date(),
      action: 'generate-merchant-insight',
      actorId,
      requestId,
      promptTemplate,
      inputData,
      rawResponse: JSON.stringify(mockOutput),
      parsedResponse: mockOutput,
      confidenceScore: 98,
      latencyMs: Date.now() - startTime,
      status: 'success',
    });

    return mockOutput;
  }

  try {
    const { text, latencyMs } = await generateContentWithRetry(prompt, responseSchema);
    const rawParsed = JSON.parse(text);

    const parsed = merchantInsightResponseSchema.safeParse(rawParsed);
    if (!parsed.success) {
      throw new Error(`Zod validation failure: ${JSON.stringify(parsed.error.flatten())}`);
    }

    const insights = parsed.data;

    await AIAuditLog.create({
      timestamp: new Date(),
      action: 'generate-merchant-insight',
      actorId,
      requestId,
      promptTemplate,
      inputData,
      rawResponse: text,
      parsedResponse: insights,
      confidenceScore: 92,
      latencyMs,
      status: 'success',
    });

    return insights;
  } catch (err: any) {
    const latencyMs = Date.now() - startTime;
    logger.error('[AI Service] Failed to generate merchant insights, returning fallback.', { error: err.message });

    await AIAuditLog.create({
      timestamp: new Date(),
      action: 'generate-merchant-insight',
      actorId,
      requestId,
      promptTemplate,
      inputData,
      validationErrors: err.message,
      latencyMs,
      status: 'failure',
    });

    return {
      revenueTrendNarrative: 'Consistent steady activity observed across recent transaction lists.',
      topCategories: ['General Services'],
      pricingSuggestions: ['Consider standard progressive milestone payments.'],
      peakHours: 'Business standard hours',
      retentionSignals: 'Reliable completion records suggest steady customer loyalty.',
    };
  }
}

/**
 * Suggest optimal min/max price and rationale for a specific service description
 */
export async function suggestPricingForService(
  description: string,
  category: string,
  actorId: string = 'system',
  requestId?: string
): Promise<PricingSuggestion> {
  const startTime = Date.now();
  const promptTemplate = `Analyze this service description: "{{description}}" in the category: "{{category}}". Suggest an optimal ADA pricing range in Lovelace (1 ADA = 1,000,000 Lovelace) based on standard marketplace benchmarks.`;
  const prompt = promptTemplate.replace('{{category}}', category).replace('{{description}}', description);

  const responseSchema = {
    type: 'OBJECT',
    properties: {
      suggestedMinLovelace: { type: 'INTEGER' },
      suggestedMaxLovelace: { type: 'INTEGER' },
      benchmarkContext: { type: 'STRING' },
      rationale: { type: 'STRING' },
    },
    required: ['suggestedMinLovelace', 'suggestedMaxLovelace', 'benchmarkContext', 'rationale'],
  };

  const inputData = { description, category };

  if (isMockMode) {
    const mockOutput: PricingSuggestion = {
      suggestedMinLovelace: 50_000_000, // 50 ADA
      suggestedMaxLovelace: 150_000_000, // 150 ADA
      benchmarkContext: 'Similar digital design and consultation services typically price between 40 to 160 ADA on global networks.',
      rationale: 'Based on complexity and the standard hourly commitment of 3-5 hours, a rate within this range secures fair value for both parties.',
    };

    await AIAuditLog.create({
      timestamp: new Date(),
      action: 'suggest-pricing-for-service',
      actorId,
      requestId,
      promptTemplate,
      inputData,
      rawResponse: JSON.stringify(mockOutput),
      parsedResponse: mockOutput,
      confidenceScore: 92,
      latencyMs: Date.now() - startTime,
      status: 'success',
    });

    return mockOutput;
  }

  try {
    const { text, latencyMs } = await generateContentWithRetry(prompt, responseSchema);
    const rawParsed = JSON.parse(text);

    const parsed = pricingSuggestionResponseSchema.safeParse(rawParsed);
    if (!parsed.success) {
      throw new Error(`Zod validation failure: ${JSON.stringify(parsed.error.flatten())}`);
    }

    const suggestion = parsed.data;

    await AIAuditLog.create({
      timestamp: new Date(),
      action: 'suggest-pricing-for-service',
      actorId,
      requestId,
      promptTemplate,
      inputData,
      rawResponse: text,
      parsedResponse: suggestion,
      confidenceScore: 88,
      latencyMs,
      status: 'success',
    });

    return suggestion;
  } catch (err: any) {
    const latencyMs = Date.now() - startTime;
    logger.error('[AI Service] Failed to suggest pricing, returning fallback.', { error: err.message });

    await AIAuditLog.create({
      timestamp: new Date(),
      action: 'suggest-pricing-for-service',
      actorId,
      requestId,
      promptTemplate,
      inputData,
      validationErrors: err.message,
      latencyMs,
      status: 'failure',
    });

    return {
      suggestedMinLovelace: 20_000_000, // 20 ADA
      suggestedMaxLovelace: 100_000_000, // 100 ADA
      benchmarkContext: 'Generic services on Cardano range from 10 to 100 ADA.',
      rationale: 'Fallback suggestion for standard task-based freelancing.',
    };
  }
}

function generateMilestoneId(): string {
  const date = new Date().toISOString().slice(0, 10).replace(/-/g, '');
  const suffix = Math.random().toString(36).substring(2, 8).toUpperCase();
  return `MS-${date}-${suffix}`;
}

function generateTaskId(): string {
  const date = new Date().toISOString().slice(0, 10).replace(/-/g, '');
  const suffix = Math.random().toString(36).substring(2, 8).toUpperCase();
  return `TSK-${date}-${suffix}`;
}

function getMockProjectPlan(requirements: string, totalAmountPaise: number) {
  const m1Id = generateMilestoneId();
  const m2Id = generateMilestoneId();
  const t1Id = generateTaskId();
  const t2Id = generateTaskId();
  const t3Id = generateTaskId();

  const halfAmount = Math.floor(totalAmountPaise / 2);
  const secondHalf = totalAmountPaise - halfAmount;

  return {
    projectSummary: `Scoped plan for requirements: "${requirements.substring(0, 100)}"`,
    scope: `Professional implementation of: ${requirements}`,
    milestones: [
      {
        milestoneId: m1Id,
        title: 'Requirements & Scaffold Base setup',
        description: 'Establish repository structure, initial models, and core security protocols.',
        amountPaise: halfAmount,
        status: 'pending' as const,
        timelineEstimateOptimisticDays: 3,
        timelineEstimateRealisticDays: 5,
        timelineEstimateConservativeDays: 7,
        deliverables: ['GitHub repository setup', 'Database migrations', 'Security baseline validation'],
        validationCriteria: ['Clean compile with zero static analysis errors', 'Successfully run unit tests'],
        successConditions: ['All initial endpoints return status 200 OK'],
        githubAuditRequirements: {
          requiredFiles: ['package.json', 'src/server.ts', 'src/config/db.ts'],
          requiredFeatures: ['Database connection', 'Basic routing'],
          requiredTests: ['src/tests/health.test.ts'],
          requiredDocumentation: ['README.md', 'DEVELOPER_RUNBOOK.md'],
        },
      },
      {
        milestoneId: m2Id,
        title: 'Core Business Logic & Final Handover',
        description: 'Complete backend APIs, client UI wiring, and automated QA audits.',
        amountPaise: secondHalf,
        status: 'pending' as const,
        timelineEstimateOptimisticDays: 5,
        timelineEstimateRealisticDays: 7,
        timelineEstimateConservativeDays: 10,
        deliverables: ['Full frontend screen suite integration', 'Production telemetry dashboard'],
        validationCriteria: ['Verified screen-to-backend live API data flows', 'Lumina smart audit pass'],
        successConditions: ['Successful user end-to-end sandbox purchase flow'],
        githubAuditRequirements: {
          requiredFiles: ['src/routes/project.routes.ts', 'lib/features/escrow/presentation/escrow_builder_screen.dart'],
          requiredFeatures: ['AI planning matching state machine flows', 'Riverpod caching'],
          requiredTests: ['src/tests/projectPlan.test.ts'],
          requiredDocumentation: ['docs/PLANNING_AGENT.md'],
        },
      },
    ],
    tasks: [
      {
        taskId: t1Id,
        title: 'Database Schema Design',
        description: 'Design the Mongoose schemas for project planning and audit trails.',
        estimatedHours: 4,
        priority: 'high' as const,
        acceptanceCriteria: ['Must link ProjectPlan to Invoice and Dispute collections'],
        githubAuditRequirements: {
          requiredFiles: ['server/src/models/ProjectPlan.ts'],
          requiredFeatures: ['Project plan DB schemas'],
          requiredTests: ['tests/models/projectPlan.test.ts'],
          requiredDocumentation: ['README.md'],
        },
      },
      {
        taskId: t2Id,
        title: 'Gemini Agent Orchestration',
        description: 'Wire up Gemini structured output prompts and Zod response checkers.',
        estimatedHours: 8,
        priority: 'high' as const,
        acceptanceCriteria: ['Successfully parse timeline arrays and confidence scores'],
        githubAuditRequirements: {
          requiredFiles: ['server/src/services/ai.service.ts'],
          requiredFeatures: ['Gemini generation'],
          requiredTests: ['tests/services/projectPlan.test.ts'],
          requiredDocumentation: ['README.md'],
        },
      },
      {
        taskId: t3Id,
        title: 'Frontend Wizard Integration',
        description: 'Integrate the planner step directly into the Escrow Builder Flutter UI.',
        estimatedHours: 12,
        priority: 'medium' as const,
        acceptanceCriteria: ['Milestones pre-populate subsequent steps without re-entry'],
        githubAuditRequirements: {
          requiredFiles: ['lib/features/escrow/presentation/escrow_builder_screen.dart'],
          requiredFeatures: ['Wizard integration'],
          requiredTests: [],
          requiredDocumentation: ['README.md'],
        },
      },
    ],
    requirementsBreakdown: [
      {
        requirement: 'Project Planning Database Schema',
        linkedMilestones: [m1Id],
        linkedTasks: [t1Id],
      },
      {
        requirement: 'AI Planning Engine',
        linkedMilestones: [m1Id, m2Id],
        linkedTasks: [t2Id],
      },
      {
        requirement: 'Pre-filled Escrow Builder UI',
        linkedMilestones: [m2Id],
        linkedTasks: [t3Id],
      },
    ],
    requirementTrace: [
      {
        requirementId: 'REQ-001',
        requirement: 'Project Planning Database Schema',
        milestoneIds: [m1Id],
        taskIds: [t1Id],
        githubAuditRequirements: {
          requiredFiles: ['server/src/models/ProjectPlan.ts'],
          requiredFeatures: ['Project plan DB schemas'],
          requiredTests: ['tests/models/projectPlan.test.ts'],
          requiredDocumentation: ['README.md'],
        },
      },
      {
        requirementId: 'REQ-002',
        requirement: 'AI Planning Engine',
        milestoneIds: [m1Id, m2Id],
        taskIds: [t2Id],
        githubAuditRequirements: {
          requiredFiles: ['server/src/services/ai.service.ts'],
          requiredFeatures: ['Gemini generation'],
          requiredTests: ['tests/services/projectPlan.test.ts'],
          requiredDocumentation: ['README.md'],
        },
      },
      {
        requirementId: 'REQ-003',
        requirement: 'Pre-filled Escrow Builder UI',
        milestoneIds: [m2Id],
        taskIds: [t3Id],
        githubAuditRequirements: {
          requiredFiles: ['lib/features/escrow/presentation/escrow_builder_screen.dart'],
          requiredFeatures: ['Wizard integration'],
          requiredTests: [],
          requiredDocumentation: ['README.md'],
        },
      },
    ],
    timeline: {
      optimisticDays: 8,
      realisticDays: 12,
      conservativeDays: 17,
      summary: 'Timelines reflect a two-phased delivery with parallel API and UI development cycles.',
    },
    acceptanceCriteria: [
      '100% of milestones completed and released',
      'Zero static analysis warnings in Flutter or Node codebase',
      'Successful mock/real integration verification',
    ],
    riskFactors: [
      'Token price volatility during lock duration: mitigated by progressive release structures',
      'Downstream service integration limits: mitigated by local caching and fallback layers',
    ],
    planningConfidence: 95,
    assumptions: [
      'Developer has access to valid Gemini API keys',
      'Mongoose connection remains stable throughout session lifetime',
    ],
    unknowns: [
      'Network block verification confirmation time variation',
    ],
    budgetAllocation: [
      { category: 'Design', percentage: 20, amountPaise: Math.round(totalAmountPaise * 0.2) },
      { category: 'Development', percentage: 60, amountPaise: Math.round(totalAmountPaise * 0.6) },
      { category: 'QA & Security', percentage: 20, amountPaise: totalAmountPaise - Math.round(totalAmountPaise * 0.2) - Math.round(totalAmountPaise * 0.6) },
    ],
    escrowPlan: {
      structure: 'Progressive Release Escrow',
      rationale: 'Mitigates counterparty risk by dividing the project into small, auditable steps.',
    },
  };
}

export async function generateProjectPlan(
  requirements: string,
  totalAmountPaise: number,
  merchantMongoId: string,
  customerId?: string,
  actorId: string = 'system',
  requestId?: string
): Promise<any> {
  const startTime = Date.now();
  const promptTemplate = `You are an expert technical program manager and blockchain architect.
Analyze the following requirements and budget to generate a structured project plan:

Requirements: "{{requirements}}"
Total Budget: {{totalAmount}} Paise.

You MUST return a structured JSON response conforming strictly to the requested schema. No free-form text.
Timelines must estimate optimistic, realistic, and conservative values in days.
All milestone percentages must sum to exactly 100%. All budgetAllocation percentages must sum to exactly 100%.
Milestone deliverables, validation criteria, success conditions, and future GitHub audit requirements (required files, features, tests, docs) must be detailed.
All tasks must have githubAuditRequirements detailing required files, features, tests, and documentation.
Requirements breakdown must map requirements to milestone titles and task titles.
Provide assumptions, unknowns, risk factors, and planning confidence (0-100).`;

  const prompt = promptTemplate
    .replace('{{requirements}}', requirements)
    .replace('{{totalAmount}}', String(totalAmountPaise));

  const responseSchema = {
    type: 'OBJECT',
    properties: {
      projectSummary: { type: 'STRING' },
      scope: { type: 'STRING' },
      milestones: {
        type: 'ARRAY',
        items: {
          type: 'OBJECT',
          properties: {
            title: { type: 'STRING' },
            description: { type: 'STRING' },
            percentage: { type: 'INTEGER' },
            timelineEstimateOptimisticDays: { type: 'INTEGER' },
            timelineEstimateRealisticDays: { type: 'INTEGER' },
            timelineEstimateConservativeDays: { type: 'INTEGER' },
            deliverables: { type: 'ARRAY', items: { type: 'STRING' } },
            validationCriteria: { type: 'ARRAY', items: { type: 'STRING' } },
            successConditions: { type: 'ARRAY', items: { type: 'STRING' } },
            githubAuditRequirements: {
              type: 'OBJECT',
              properties: {
                requiredFiles: { type: 'ARRAY', items: { type: 'STRING' } },
                requiredFeatures: { type: 'ARRAY', items: { type: 'STRING' } },
                requiredTests: { type: 'ARRAY', items: { type: 'STRING' } },
                requiredDocumentation: { type: 'ARRAY', items: { type: 'STRING' } },
              },
              required: ['requiredFiles', 'requiredFeatures', 'requiredTests', 'requiredDocumentation'],
            },
          },
          required: [
            'title',
            'description',
            'percentage',
            'timelineEstimateOptimisticDays',
            'timelineEstimateRealisticDays',
            'timelineEstimateConservativeDays',
            'deliverables',
            'validationCriteria',
            'successConditions',
            'githubAuditRequirements',
          ],
        },
      },
      tasks: {
        type: 'ARRAY',
        items: {
          type: 'OBJECT',
          properties: {
            title: { type: 'STRING' },
            description: { type: 'STRING' },
            estimatedHours: { type: 'INTEGER' },
            priority: { type: 'STRING', enum: ['low', 'medium', 'high'] },
            acceptanceCriteria: { type: 'ARRAY', items: { type: 'STRING' } },
            githubAuditRequirements: {
              type: 'OBJECT',
              properties: {
                requiredFiles: { type: 'ARRAY', items: { type: 'STRING' } },
                requiredFeatures: { type: 'ARRAY', items: { type: 'STRING' } },
                requiredTests: { type: 'ARRAY', items: { type: 'STRING' } },
                requiredDocumentation: { type: 'ARRAY', items: { type: 'STRING' } },
              },
              required: ['requiredFiles', 'requiredFeatures', 'requiredTests', 'requiredDocumentation'],
            },
          },
          required: ['title', 'description', 'estimatedHours', 'priority', 'acceptanceCriteria', 'githubAuditRequirements'],
        },
      },
      requirementsBreakdown: {
        type: 'ARRAY',
        items: {
          type: 'OBJECT',
          properties: {
            requirement: { type: 'STRING' },
            linkedMilestoneTitles: { type: 'ARRAY', items: { type: 'STRING' } },
            linkedTaskTitles: { type: 'ARRAY', items: { type: 'STRING' } },
          },
          required: ['requirement', 'linkedMilestoneTitles', 'linkedTaskTitles'],
        },
      },
      timeline: {
        type: 'OBJECT',
        properties: {
          optimisticDays: { type: 'INTEGER' },
          realisticDays: { type: 'INTEGER' },
          conservativeDays: { type: 'INTEGER' },
          summary: { type: 'STRING' },
        },
        required: ['optimisticDays', 'realisticDays', 'conservativeDays', 'summary'],
      },
      acceptanceCriteria: { type: 'ARRAY', items: { type: 'STRING' } },
      riskFactors: { type: 'ARRAY', items: { type: 'STRING' } },
      budgetAllocation: {
        type: 'ARRAY',
        items: {
          type: 'OBJECT',
          properties: {
            category: { type: 'STRING' },
            percentage: { type: 'INTEGER' },
          },
          required: ['category', 'percentage'],
        },
      },
      escrowPlan: {
        type: 'OBJECT',
        properties: {
          structure: { type: 'STRING' },
          rationale: { type: 'STRING' },
        },
        required: ['structure', 'rationale'],
      },
      planningConfidence: { type: 'INTEGER' },
      assumptions: { type: 'ARRAY', items: { type: 'STRING' } },
      unknowns: { type: 'ARRAY', items: { type: 'STRING' } },
    },
    required: [
      'projectSummary',
      'scope',
      'milestones',
      'tasks',
      'requirementsBreakdown',
      'timeline',
      'acceptanceCriteria',
      'riskFactors',
      'budgetAllocation',
      'escrowPlan',
      'planningConfidence',
      'assumptions',
      'unknowns',
    ],
  };

  const inputData = { requirements, totalAmountPaise };

  if (isMockMode) {
    const mockOutput = getMockProjectPlan(requirements, totalAmountPaise);
    return mockOutput;
  }

  try {
    const { text, latencyMs } = await generateContentWithRetry(prompt, responseSchema);
    const rawParsed = JSON.parse(text);

    const parsed = projectPlanResponseSchema.safeParse(rawParsed);
    if (!parsed.success) {
      logger.error('[AI Service] Project Plan response validation failed', { detail: JSON.stringify(parsed.error.flatten()) });
      throw new Error(`Zod validation failure: ${JSON.stringify(parsed.error.flatten())}`);
    }

    const aiPlan = parsed.data;

    // Process Milestones: generate milestoneId, assign amountPaise
    const milestones = aiPlan.milestones.map((m) => {
      const msId = generateMilestoneId();
      // Calculate amount based on percentage
      const amountPaise = Math.round(totalAmountPaise * (m.percentage / 100));
      return {
        milestoneId: msId,
        title: m.title,
        description: m.description,
        amountPaise,
        status: 'pending' as const,
        timelineEstimateOptimisticDays: m.timelineEstimateOptimisticDays,
        timelineEstimateRealisticDays: m.timelineEstimateRealisticDays,
        timelineEstimateConservativeDays: m.timelineEstimateConservativeDays,
        deliverables: m.deliverables,
        validationCriteria: m.validationCriteria,
        successConditions: m.successConditions,
        githubAuditRequirements: m.githubAuditRequirements,
        _tempTitle: m.title,
      };
    });

    // Normalize milestone amountPaise to match exactly totalAmountPaise
    const sumPaise = milestones.reduce((sum, m) => sum + m.amountPaise, 0);
    if (sumPaise !== totalAmountPaise && milestones.length > 0) {
      const diff = totalAmountPaise - sumPaise;
      milestones[milestones.length - 1].amountPaise += diff;
    }

    // Process Tasks: generate taskId
    const tasks = aiPlan.tasks.map((t) => {
      const taskId = generateTaskId();
      return {
        taskId,
        title: t.title,
        description: t.description,
        estimatedHours: t.estimatedHours,
        priority: t.priority,
        acceptanceCriteria: t.acceptanceCriteria,
        githubAuditRequirements: t.githubAuditRequirements,
        _tempTitle: t.title,
      };
    });

    // Map requirementsBreakdown to milestoneIds and taskIds
    const requirementsBreakdown = aiPlan.requirementsBreakdown.map((rb) => {
      const linkedMilestones = rb.linkedMilestoneTitles
        .map((title) => {
          const match = milestones.find((m) => m._tempTitle.toLowerCase().includes(title.toLowerCase()) || title.toLowerCase().includes(m._tempTitle.toLowerCase()));
          return match ? match.milestoneId : null;
        })
        .filter((id): id is string => id !== null);

      const linkedTasks = rb.linkedTaskTitles
        .map((title) => {
          const match = tasks.find((t) => t._tempTitle.toLowerCase().includes(title.toLowerCase()) || title.toLowerCase().includes(t._tempTitle.toLowerCase()));
          return match ? match.taskId : null;
        })
        .filter((id): id is string => id !== null);

      return {
        requirement: rb.requirement,
        linkedMilestones,
        linkedTasks,
      };
    });

    // Map requirementTrace to milestoneIds, taskIds and aggregate githubAuditRequirements
    const requirementTrace = aiPlan.requirementsBreakdown.map((rb, index) => {
      const requirementId = `REQ-${String(index + 1).padStart(3, '0')}`;
      
      const milestoneIds = rb.linkedMilestoneTitles
        .map((title) => {
          const match = milestones.find((m) => m._tempTitle.toLowerCase().includes(title.toLowerCase()) || title.toLowerCase().includes(m._tempTitle.toLowerCase()));
          return match ? match.milestoneId : null;
        })
        .filter((id): id is string => id !== null);

      const taskIds = rb.linkedTaskTitles
        .map((title) => {
          const match = tasks.find((t) => t._tempTitle.toLowerCase().includes(title.toLowerCase()) || title.toLowerCase().includes(t._tempTitle.toLowerCase()));
          return match ? match.taskId : null;
        })
        .filter((id): id is string => id !== null);

      // Aggregate githubAuditRequirements from linked tasks
      const requiredFiles = new Set<string>();
      const requiredFeatures = new Set<string>();
      const requiredTests = new Set<string>();
      const requiredDocumentation = new Set<string>();

      taskIds.forEach((tId) => {
        const task = tasks.find((tk) => tk.taskId === tId);
        if (task && task.githubAuditRequirements) {
          (task.githubAuditRequirements.requiredFiles || []).forEach((f) => requiredFiles.add(f));
          (task.githubAuditRequirements.requiredFeatures || []).forEach((f) => requiredFeatures.add(f));
          (task.githubAuditRequirements.requiredTests || []).forEach((f) => requiredTests.add(f));
          (task.githubAuditRequirements.requiredDocumentation || []).forEach((f) => requiredDocumentation.add(f));
        }
      });

      return {
        requirementId,
        requirement: rb.requirement,
        milestoneIds,
        taskIds,
        githubAuditRequirements: {
          requiredFiles: Array.from(requiredFiles),
          requiredFeatures: Array.from(requiredFeatures),
          requiredTests: Array.from(requiredTests),
          requiredDocumentation: Array.from(requiredDocumentation),
        },
      };
    });

    // Clean up temp mapping titles
    milestones.forEach((m: any) => delete m._tempTitle);
    tasks.forEach((t: any) => delete t._tempTitle);

    // Map budget allocation amountPaise
    const budgetAllocation = aiPlan.budgetAllocation.map((b) => {
      const amountPaise = Math.round(totalAmountPaise * (b.percentage / 100));
      return {
        category: b.category,
        percentage: b.percentage,
        amountPaise,
      };
    });

    // Normalize budget allocation sum to totalAmountPaise
    const sumBudget = budgetAllocation.reduce((sum, b) => sum + b.amountPaise, 0);
    if (sumBudget !== totalAmountPaise && budgetAllocation.length > 0) {
      const diff = totalAmountPaise - sumBudget;
      budgetAllocation[budgetAllocation.length - 1].amountPaise += diff;
    }

    const processedPlan = {
      projectSummary: aiPlan.projectSummary,
      scope: aiPlan.scope,
      milestones,
      tasks,
      requirementsBreakdown,
      requirementTrace,
      timeline: aiPlan.timeline,
      acceptanceCriteria: aiPlan.acceptanceCriteria,
      riskFactors: aiPlan.riskFactors,
      planningConfidence: aiPlan.planningConfidence,
      assumptions: aiPlan.assumptions,
      unknowns: aiPlan.unknowns,
      budgetAllocation,
      escrowPlan: aiPlan.escrowPlan,
    };

    // Log success
    await AIAuditLog.create({
      timestamp: new Date(),
      action: 'generate-project-plan',
      actorId,
      requestId,
      promptTemplate,
      inputData,
      rawResponse: text,
      parsedResponse: processedPlan,
      confidenceScore: aiPlan.planningConfidence,
      latencyMs,
      status: 'success',
    });

    return processedPlan;
  } catch (err: any) {
    const latencyMs = Date.now() - startTime;
    logger.error('[AI Service] Failed to generate project plan, running fallback', { error: err.message });

    await AIAuditLog.create({
      timestamp: new Date(),
      action: 'generate-project-plan',
      actorId,
      requestId,
      promptTemplate,
      inputData,
      validationErrors: err.message,
      latencyMs,
      status: 'failure',
    });

    // Fallback to mock plan
    return getMockProjectPlan(requirements, totalAmountPaise);
  }
}



export async function auditMilestoneCompletion(
  snapshot: any,
  projectPlan: any,
  milestoneId: string,
  actorId: string = 'system',
  requestId?: string
): Promise<GitHubAuditResponse> {
  const startTime = Date.now();
  const promptTemplate = `[Prompt Version: ${PROMPT_VERSIONS.AUDIT_MILESTONE}] You are a professional codebase auditor and smart contract release safety advisor.
You are auditing milestone "${milestoneId}" for a project plan.

Project Requirements:
\${JSON.stringify(projectPlan.requirements)}

Milestones & Requirements Breakdown:
\${JSON.stringify(projectPlan.requirementTrace || projectPlan.requirementTraceability || [])}

Target Milestone to Audit:
\${JSON.stringify(projectPlan.milestones.find((m: any) => m.milestoneId === milestoneId) || {})}

Repository Code Snapshot (GitHub MCP Source of Truth):
- Connected URL: \${snapshot.repositoryUrl}
- Active Branch: \${snapshot.branch}
- Repository Trees/Files: \${JSON.stringify(snapshot.repositoryTree)}
- Commit Hashes: \${JSON.stringify(snapshot.commitHashes)}
- Pull Request reviews & comments: \${JSON.stringify(snapshot.prMetadata)}
- GitHub Actions Workflow Runs: \${JSON.stringify(snapshot.workflowRuns)}
- Release Tags: \${JSON.stringify(snapshot.releaseTags)}

CRITICAL VERIFICATION RULES:
1. Compare the connected repository evidence (files, commits, PR comments/reviews) against the milestone githubAuditRequirements.
2. For each requirement associated with this milestone, compile a detailed RequirementTraceMatrix entry:
   - Identify evidenceFiles (files that implement it), evidenceCommits (commits that added/modified it), and evidencePRs.
   - Set status (PASSED, PARTIAL, FAILED, INSUFFICIENT_EVIDENCE) and completionPercentage (0-100).
3. If any CI/CD workflow run is in a failed status (conclusion: 'failure' or similar), the overall auditStatus MUST NOT be 'PASSED'. Set it to 'FAILED' or 'PARTIALLY_COMPLETED'.
4. Calculate the releaseConfidenceScore (0-100) using the formula:
   releaseConfidenceScore = (0.4 * implementationCoverage) + (0.3 * requirementCompletionRate) + (0.15 * CI_Success_Rate) - (0.15 * Security_Issues_Count * 10)
   Ensure the score is bound between 0 and 100.
5. Set releaseRecommendation:
   - RECOMMEND_RELEASE: Audit status is PASSED and releaseConfidenceScore >= 80.
   - RECOMMEND_MINOR_FIXES: Audit status is PARTIALLY_COMPLETED/PASSED but has minor issues or releaseConfidenceScore between 70 and 79.
   - RECOMMEND_MAJOR_REWORK: Audit status is FAILED or has failing CI/CD, or releaseConfidenceScore between 40 and 69.
   - RECOMMEND_DISPUTE_REVIEW: Insufficient evidence, major security breaches, or releaseConfidenceScore < 40.
6. Provide comprehensive explainability fields.

Return your response strictly as a JSON object matching this schema:
\${JSON.stringify({
  auditStatus: 'PASSED | PARTIALLY_COMPLETED | FAILED | INSUFFICIENT_EVIDENCE',
  releaseRecommendation: 'RECOMMEND_RELEASE | RECOMMEND_MINOR_FIXES | RECOMMEND_MAJOR_REWORK | RECOMMEND_DISPUTE_REVIEW',
  confidenceScore: 90,
  releaseConfidenceScore: 85,
  auditSummary: 'Summary of the audit findings',
  findings: 'Detailed technical findings',
  implementationCoverage: 85,
  missingRequirements: ['list of missing requirements'],
  securityIssues: ['list of security issues'],
  performanceIssues: ['list of performance issues'],
  architectureIssues: ['list of architecture issues'],
  recommendedActions: ['actions to take'],
  requirementTraceMatrix: [
    {
      requirementId: 'REQ-001',
      requirementText: 'Requirement text',
      completionPercentage: 100,
      confidenceScore: 95,
      evidenceFiles: ['src/file.ts'],
      evidenceCommits: ['sha123'],
      evidencePRs: ['1'],
      status: 'PASSED',
    },
  ],
  explainability: {
    whyVerdictAssigned: 'Explain the reason behind this verdict',
    evidenceUsed: 'Explain what evidence was verified',
    missingImplementation: 'Describe what was missing',
    suggestedFixes: 'Describe what to fix',
  },
})}`;

  const inputData = { milestoneId, projectPlanId: projectPlan.planId, promptVersion: PROMPT_VERSIONS.AUDIT_MILESTONE };

  if (isMockMode) {
    const mockOutput: GitHubAuditResponse = {
      auditStatus: 'PASSED',
      releaseRecommendation: 'RECOMMEND_RELEASE',
      confidenceScore: 95,
      releaseConfidenceScore: 90,
      auditSummary: 'Milestone requirements have been fully verified and tested. Code quality is high, and all unit tests pass successfully.',
      findings: 'All core modules for this milestone are fully implemented. Lint checks and security scans are passing. Verification matrix links requirements to specific codebase entries.',
      implementationCoverage: 100,
      missingRequirements: [],
      securityIssues: [],
      performanceIssues: [],
      architectureIssues: [],
      recommendedActions: ['Proceed with release of funds from escrow.'],
      requirementTraceMatrix: (projectPlan.requirementTrace || []).map((r: any) => ({
        requirementId: r.requirementId,
        requirementText: r.requirement,
        completionPercentage: 100,
        confidenceScore: 95,
        evidenceFiles: r.githubAuditRequirements?.requiredFiles || ['src/server.ts'],
        evidenceCommits: snapshot.commitHashes || ['c8f391a2bb28384818cc65fa28a8a65bb919a3b2'],
        evidencePRs: ['1'],
        status: 'PASSED',
      })),
      explainability: {
        whyVerdictAssigned: 'All requirements have corresponding verified code files and commits. The build and test pipelines are completely green.',
        evidenceUsed: 'Inspected repo file list, verified commits, and checked PR reviews.',
        missingImplementation: 'None.',
        suggestedFixes: 'None.',
      },
    };

    await AIAuditLog.create({
      timestamp: new Date(),
      action: 'audit-milestone',
      actorId,
      requestId,
      promptTemplate,
      inputData,
      rawResponse: JSON.stringify(mockOutput),
      parsedResponse: mockOutput,
      confidenceScore: 100,
      latencyMs: Date.now() - startTime,
      status: 'success',
    });

    return mockOutput;
  }

  try {
    const { text, latencyMs } = await generateContentWithRetry(
      promptTemplate,
      {
        type: 'OBJECT',
        properties: {
          auditStatus: { type: 'STRING' },
          releaseRecommendation: { type: 'STRING' },
          confidenceScore: { type: 'INTEGER' },
          releaseConfidenceScore: { type: 'INTEGER' },
          auditSummary: { type: 'STRING' },
          findings: { type: 'STRING' },
          implementationCoverage: { type: 'INTEGER' },
          missingRequirements: { type: 'ARRAY', items: { type: 'STRING' } },
          securityIssues: { type: 'ARRAY', items: { type: 'STRING' } },
          performanceIssues: { type: 'ARRAY', items: { type: 'STRING' } },
          architectureIssues: { type: 'ARRAY', items: { type: 'STRING' } },
          recommendedActions: { type: 'ARRAY', items: { type: 'STRING' } },
          requirementTraceMatrix: {
            type: 'ARRAY',
            items: {
              type: 'OBJECT',
              properties: {
                requirementId: { type: 'STRING' },
                requirementText: { type: 'STRING' },
                completionPercentage: { type: 'INTEGER' },
                confidenceScore: { type: 'INTEGER' },
                evidenceFiles: { type: 'ARRAY', items: { type: 'STRING' } },
                evidenceCommits: { type: 'ARRAY', items: { type: 'STRING' } },
                evidencePRs: { type: 'ARRAY', items: { type: 'STRING' } },
                status: { type: 'STRING' },
              },
              required: [
                'requirementId',
                'requirementText',
                'completionPercentage',
                'confidenceScore',
                'evidenceFiles',
                'evidenceCommits',
                'evidencePRs',
                'status',
              ],
            },
          },
          explainability: {
            type: 'OBJECT',
            properties: {
              whyVerdictAssigned: { type: 'STRING' },
              evidenceUsed: { type: 'STRING' },
              missingImplementation: { type: 'STRING' },
              suggestedFixes: { type: 'STRING' },
            },
            required: ['whyVerdictAssigned', 'evidenceUsed', 'missingImplementation', 'suggestedFixes'],
          },
        },
        required: [
          'auditStatus',
          'releaseRecommendation',
          'confidenceScore',
          'releaseConfidenceScore',
          'auditSummary',
          'findings',
          'implementationCoverage',
          'missingRequirements',
          'securityIssues',
          'performanceIssues',
          'architectureIssues',
          'recommendedActions',
          'requirementTraceMatrix',
          'explainability',
        ],
      },
      3,
      'gemini-2.5-pro'
    );

    const rawParsed = JSON.parse(text);
    const parsed = githubAuditResponseSchema.safeParse(rawParsed);

    if (!parsed.success) {
      throw new Error(`Zod audit schema validation failed: \${parsed.error.message}`);
    }

    await AIAuditLog.create({
      timestamp: new Date(),
      action: 'audit-milestone',
      actorId,
      requestId,
      promptTemplate,
      inputData,
      rawResponse: text,
      parsedResponse: parsed.data,
      confidenceScore: parsed.data.confidenceScore,
      latencyMs: Date.now() - startTime,
      status: 'success',
    });

    return parsed.data;
  } catch (err: any) {
    const latencyMs = Date.now() - startTime;
    logger.error('[AI Service] Failed to audit milestone, running fallback', { error: err.message });

    await AIAuditLog.create({
      timestamp: new Date(),
      action: 'audit-milestone',
      actorId,
      requestId,
      promptTemplate,
      inputData,
      validationErrors: err.message,
      latencyMs,
      status: 'failure',
    });

    // High fidelity fallback when live Gemini call fails
    return {
      auditStatus: 'INSUFFICIENT_EVIDENCE',
      releaseRecommendation: 'RECOMMEND_DISPUTE_REVIEW',
      confidenceScore: 0,
      releaseConfidenceScore: 0,
      auditSummary: `Failed to compile automated audit: \${err.message}`,
      findings: 'The automated code audit agent experienced an internal parsing exception.',
      implementationCoverage: 0,
      missingRequirements: [],
      securityIssues: [],
      performanceIssues: [],
      architectureIssues: [],
      recommendedActions: ['Please manually verify code commits or re-run the verification agent.'],
      requirementTraceMatrix: (projectPlan.requirementTrace || []).map((r: any) => ({
        requirementId: r.requirementId,
        requirementText: r.requirement,
        completionPercentage: 0,
        confidenceScore: 0,
        evidenceFiles: [],
        evidenceCommits: [],
        evidencePRs: [],
        status: 'INSUFFICIENT_EVIDENCE',
      })),
      explainability: {
        whyVerdictAssigned: 'Evaluation failed due to an internal error.',
        evidenceUsed: 'None.',
        missingImplementation: 'Unknown.',
        suggestedFixes: 'Contact system administrator.',
      },
    };
  }
}
