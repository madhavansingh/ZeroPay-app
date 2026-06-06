import { describe, it, expect, vi } from 'vitest';

vi.mock('../../src/config/env', () => ({
  env: {
    NODE_ENV: 'test',
    GEMINI_API_KEY: 'mock-gemini-key',
  },
}));

vi.mock('../../src/models/AIAuditLog', () => ({
  AIAuditLog: {
    create: vi.fn().mockResolvedValue({}),
  },
}));

import { generateProjectPlan } from '../../src/services/ai.service';

describe('Project Planning Service Tests', () => {
  it('should generate a structured project plan with milestones, tasks, and traceability', async () => {
    const plan = await generateProjectPlan(
      'Build a fintech dashboard with analytics and authentication',
      50000, // ₹500.00
      '6650dbcb5e0cf7001bb05abc'
    );

    expect(plan.projectSummary).toBeDefined();
    expect(plan.scope).toBeDefined();
    expect(plan.milestones).toHaveLength(2);
    expect(plan.tasks).toHaveLength(3);
    
    // Milestones validation
    expect(plan.milestones[0].milestoneId).toMatch(/^MS-\d{8}-[A-Z0-9]{6}$/);
    expect(plan.milestones[0].amountPaise).toBe(25000);
    expect(plan.milestones[0].githubAuditRequirements).toBeDefined();
    expect(plan.milestones[0].githubAuditRequirements.requiredFiles).toContain('package.json');

    // Tasks validation
    expect(plan.tasks[0].taskId).toMatch(/^TSK-\d{8}-[A-Z0-9]{6}$/);
    expect(plan.tasks[0].estimatedHours).toBe(4);
    expect(plan.tasks[0].priority).toBe('high');
    expect(plan.tasks[0].githubAuditRequirements).toBeDefined();
    expect(plan.tasks[0].githubAuditRequirements.requiredFiles).toContain('server/src/models/ProjectPlan.ts');

    // Traceability validation
    expect(plan.requirementsBreakdown).toHaveLength(3);
    expect(plan.requirementsBreakdown[0].requirement).toBeDefined();
    expect(plan.requirementsBreakdown[0].linkedMilestones).toContain(plan.milestones[0].milestoneId);

    // RequirementTrace validation
    expect(plan.requirementTrace).toBeDefined();
    expect(plan.requirementTrace).toHaveLength(3);
    expect(plan.requirementTrace[0].requirementId).toBe('REQ-001');
    expect(plan.requirementTrace[0].requirement).toBe('Project Planning Database Schema');
    expect(plan.requirementTrace[0].milestoneIds).toContain(plan.milestones[0].milestoneId);
    expect(plan.requirementTrace[0].taskIds).toContain(plan.tasks[0].taskId);
    expect(plan.requirementTrace[0].githubAuditRequirements).toBeDefined();
    expect(plan.requirementTrace[0].githubAuditRequirements.requiredFiles).toContain('server/src/models/ProjectPlan.ts');

    // Timelines
    expect(plan.timeline.optimisticDays).toBe(8);
    expect(plan.timeline.realisticDays).toBe(12);
    expect(plan.timeline.conservativeDays).toBe(17);

    // AI confidence
    expect(plan.planningConfidence).toBe(95);
    expect(plan.assumptions).toContain('Developer has access to valid Gemini API keys');
    expect(plan.unknowns).toContain('Network block verification confirmation time variation');
  });
});
