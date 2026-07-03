import { PROMPT_VERSIONS } from './ai.schemas';

export function buildMilestonesPrompt(description: string, totalAmountPaise: number): string {
  return `[Version: ${PROMPT_VERSIONS.GENERATE_MILESTONES}] You are a professional freelance project manager. Split the contract description into 2 to 5 logical milestones.
The total amount of all milestones combined MUST equal exactly ${totalAmountPaise} paise.
Contract Description: "${description}"
Ensure the sum of all 'amountPaise' equals ${totalAmountPaise} exactly.`;
}

export function buildDisputePrompt(invoiceId: string, claims: string[], evidences: string[]): string {
  return `[Version: ${PROMPT_VERSIONS.SUMMARIZE_DISPUTE}] You are an impartial commercial dispute arbitrator for an escrow platform.
Review the dispute claims and evidence for Invoice "${invoiceId}".
Claims: ${JSON.stringify(claims)}
Evidence: ${JSON.stringify(evidences)}
Provide a fair, evidence-based dispute summary and recommend a merchant/customer split percentage.`;
}

export function buildProjectPlanPrompt(requirements: string, category?: string): string {
  return `[Version: ${PROMPT_VERSIONS.AUDIT_MILESTONE}] You are a Lead Software Architect. Create a structured project plan.
Requirements: "${requirements}"
Category: "${category || 'general'}"
Generate 3 to 6 sequential milestones with acceptance criteria, percentages totaling 100%, and risk level.`;
}
