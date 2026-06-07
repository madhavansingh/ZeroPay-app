import { z } from 'zod';

export const nemotronMilestoneSchema = z.object({
  title: z.string().min(3, 'Milestone title must be at least 3 characters'),
  description: z.string().min(5, 'Milestone description must be at least 5 characters'),
  estimatedDays: z.number().int().positive('Estimated days must be positive'),
  dependencies: z.array(z.string()).default([]),
  acceptanceCriteria: z.array(z.string()).min(1, 'Milestone must have at least one acceptance criterion'),
  deliverables: z.array(z.string()).min(1, 'Milestone must have at least one deliverable'),
  percentage: z.number().min(0).max(100, 'Percentage must be between 0 and 100'),
  budgetAllocation: z.number().int().nonnegative('Budget allocation must be non-negative'),
  releaseConditions: z.array(z.string()).min(1, 'Milestone must have at least one release condition'),
  githubAuditRequirements: z.array(z.string()).min(1, 'Milestone must list at least one GitHub audit requirement file/feature'),
});

export const nemotronTaskSchema = z.object({
  title: z.string().min(3, 'Task title must be at least 3 characters'),
  description: z.string().min(5, 'Task description must be at least 5 characters'),
  estimatedHours: z.number().int().positive('Estimated hours must be positive'),
  priority: z.enum(['low', 'medium', 'high']),
  acceptanceCriteria: z.array(z.string()).min(1, 'Task must have at least one acceptance criterion'),
  githubAuditRequirements: z.array(z.string()).default([]),
});

export const nemotronRiskSchema = z.object({
  description: z.string().min(5, 'Risk description must be at least 5 characters'),
  severity: z.enum(['low', 'medium', 'high', 'critical']),
  mitigation: z.string().min(5, 'Risk mitigation must be at least 5 characters'),
});

export const nemotronTimelineSchema = z.object({
  optimisticDays: z.number().int().positive(),
  realisticDays: z.number().int().positive(),
  conservativeDays: z.number().int().positive(),
  summary: z.string().min(5),
});

export const nemotronProjectPlanSchema = z.object({
  executiveSummary: z.string().min(10, 'Executive summary is too short'),
  productVision: z.string().min(10, 'Product vision is too short'),
  functionalRequirements: z.array(z.string()).min(1, 'Must have at least one functional requirement'),
  nonFunctionalRequirements: z.array(z.string()).min(1, 'Must have at least one non-functional requirement'),
  systemArchitecture: z.string().min(10, 'System architecture details are too short'),
  databaseDesign: z.string().min(10, 'Database design details are too short'),
  apiDesign: z.string().min(10, 'API design details are too short'),
  milestones: z.array(nemotronMilestoneSchema).min(1, 'Must generate at least one milestone'),
  tasks: z.array(nemotronTaskSchema).min(1, 'Must generate at least one task'),
  acceptanceCriteria: z.array(z.string()).min(1, 'Must list overall project acceptance criteria'),
  dependencies: z.array(z.string()).default([]),
  riskAnalysis: z.array(nemotronRiskSchema).min(1, 'Must provide risk analysis'),
  timelineEstimates: nemotronTimelineSchema,
  deploymentStrategy: z.string().min(10, 'Deployment strategy details are too short'),
  testingStrategy: z.string().min(10, 'Testing strategy details are too short'),
});

export type NemotronProjectPlanInput = z.infer<typeof nemotronProjectPlanSchema>;
