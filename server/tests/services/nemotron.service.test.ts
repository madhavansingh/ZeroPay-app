import { describe, it, expect, vi, beforeEach } from 'vitest';
import axios from 'axios';

vi.mock('axios');

describe('NVIDIA Nemotron Planning Service Tests', () => {
  beforeEach(() => {
    vi.resetModules();
    vi.clearAllMocks();
  });

  it('should return a high-fidelity mock plan when in mock mode', async () => {
    vi.doMock('../../src/config/env', () => ({
      env: {
        NODE_ENV: 'test',
        NVIDIA_API_KEY: 'mock-nvidia-key',
        PLANNER_MODEL: 'nvidia/llama-3.3-nemotron-super-49b-v1',
      },
    }));

    const { generateProjectPlanWithNemotron } = await import('../../src/services/nemotron.service');

    const plan = await generateProjectPlanWithNemotron(
      'Build a decentralized web storefront',
      500000
    );

    expect(plan.executiveSummary).toContain('decentralized web storefront');
    expect(plan.milestones).toHaveLength(2);
    expect(plan.milestones[0].budgetAllocation).toBe(250000);
    expect(plan.milestones[1].budgetAllocation).toBe(250000);
    expect(plan.tasks).toHaveLength(3);
    expect(plan.functionalRequirements).toHaveLength(3);
    expect(plan.riskAnalysis).toHaveLength(1);
    expect(plan.timelineEstimates.optimisticDays).toBe(8);
  });

  it('should call NVIDIA API and return plan when API key is valid (not mock)', async () => {
    vi.doMock('../../src/config/env', () => ({
      env: {
        NODE_ENV: 'test',
        NVIDIA_API_KEY: 'nvapi-valid-real-key',
        PLANNER_MODEL: 'nvidia/llama-3.3-nemotron-super-49b-v1',
      },
    }));

    const validPlanOutput = {
      executiveSummary: 'This is a valid executive summary of the system architecture.',
      productVision: 'The product vision is to build a high performance platform.',
      functionalRequirements: ['Requirement 1'],
      nonFunctionalRequirements: ['Uptime 99.9%'],
      systemArchitecture: 'React frontend with NestJS backend.',
      databaseDesign: 'PostgreSQL database.',
      apiDesign: 'REST endpoints with OpenAPI spec.',
      milestones: [
        {
          title: 'Setup',
          description: 'Initial project setup.',
          estimatedDays: 3,
          dependencies: [],
          acceptanceCriteria: ['Setup completed.'],
          deliverables: ['Repo configured.'],
          percentage: 100,
          budgetAllocation: 500000,
          releaseConditions: ['Ready.'],
          githubAuditRequirements: ['package.json'],
        }
      ],
      tasks: [
        {
          title: 'Setup repository',
          description: 'Setup git repository and build pipeline.',
          estimatedHours: 4,
          priority: 'high',
          acceptanceCriteria: ['Pipelines green.'],
          githubAuditRequirements: ['package.json'],
        }
      ],
      acceptanceCriteria: ['All tests pass.'],
      dependencies: ['Cloud provider'],
      riskAnalysis: [
        {
          description: 'API limit.',
          severity: 'medium',
          mitigation: 'Caching.',
        }
      ],
      timelineEstimates: {
        optimisticDays: 2,
        realisticDays: 3,
        conservativeDays: 5,
        summary: 'Timeline summary.',
      },
      deploymentStrategy: 'Deploy on railway.',
      testingStrategy: 'Vitest unit tests.',
    };

    vi.mocked(axios.post).mockResolvedValueOnce({
      data: {
        choices: [
          {
            message: {
              content: JSON.stringify(validPlanOutput),
            },
          },
        ],
      },
    });

    const { generateProjectPlanWithNemotron } = await import('../../src/services/nemotron.service');

    const plan = await generateProjectPlanWithNemotron(
      'Build a decentralized web storefront',
      500000
    );

    expect(plan.executiveSummary).toBe(validPlanOutput.executiveSummary);
    expect(plan.milestones[0].title).toBe('Setup');
    expect(axios.post).toHaveBeenCalledTimes(1);
  });

  it('should successfully repair markdown-wrapped JSON response from API', async () => {
    vi.doMock('../../src/config/env', () => ({
      env: {
        NODE_ENV: 'test',
        NVIDIA_API_KEY: 'nvapi-valid-real-key',
        PLANNER_MODEL: 'nvidia/llama-3.3-nemotron-super-49b-v1',
      },
    }));

    const validPlanOutput = {
      executiveSummary: 'This is a valid executive summary of the system architecture.',
      productVision: 'The product vision is to build a high performance platform.',
      functionalRequirements: ['Requirement 1'],
      nonFunctionalRequirements: ['Uptime 99.9%'],
      systemArchitecture: 'React frontend with NestJS backend.',
      databaseDesign: 'PostgreSQL database.',
      apiDesign: 'REST endpoints with OpenAPI spec.',
      milestones: [
        {
          title: 'Setup',
          description: 'Initial project setup.',
          estimatedDays: 3,
          dependencies: [],
          acceptanceCriteria: ['Setup completed.'],
          deliverables: ['Repo configured.'],
          percentage: 100,
          budgetAllocation: 500000,
          releaseConditions: ['Ready.'],
          githubAuditRequirements: ['package.json'],
        }
      ],
      tasks: [
        {
          title: 'Setup repository',
          description: 'Setup git repository and build pipeline.',
          estimatedHours: 4,
          priority: 'high',
          acceptanceCriteria: ['Pipelines green.'],
          githubAuditRequirements: ['package.json'],
        }
      ],
      acceptanceCriteria: ['All tests pass.'],
      dependencies: ['Cloud provider'],
      riskAnalysis: [
        {
          description: 'API limit.',
          severity: 'medium',
          mitigation: 'Caching.',
        }
      ],
      timelineEstimates: {
        optimisticDays: 2,
        realisticDays: 3,
        conservativeDays: 5,
        summary: 'Timeline summary.',
      },
      deploymentStrategy: 'Deploy on railway.',
      testingStrategy: 'Vitest unit tests.',
    };

    const markdownContent = `\`\`\`json\n${JSON.stringify(validPlanOutput)}\n\`\`\``;

    vi.mocked(axios.post).mockResolvedValueOnce({
      data: {
        choices: [
          {
            message: {
              content: markdownContent,
            },
          },
        ],
      },
    });

    const { generateProjectPlanWithNemotron } = await import('../../src/services/nemotron.service');

    const plan = await generateProjectPlanWithNemotron(
      'Build a decentralized web storefront',
      500000
    );

    expect(plan.executiveSummary).toBe(validPlanOutput.executiveSummary);
    expect(axios.post).toHaveBeenCalledTimes(1);
  });

  it('should retry on initial failure and succeed if subsequent attempt works', async () => {
    vi.doMock('../../src/config/env', () => ({
      env: {
        NODE_ENV: 'test',
        NVIDIA_API_KEY: 'nvapi-valid-real-key',
        PLANNER_MODEL: 'nvidia/llama-3.3-nemotron-super-49b-v1',
      },
    }));

    const validPlanOutput = {
      executiveSummary: 'This is a valid executive summary of the system architecture.',
      productVision: 'The product vision is to build a high performance platform.',
      functionalRequirements: ['Requirement 1'],
      nonFunctionalRequirements: ['Uptime 99.9%'],
      systemArchitecture: 'React frontend with NestJS backend.',
      databaseDesign: 'PostgreSQL database.',
      apiDesign: 'REST endpoints with OpenAPI spec.',
      milestones: [
        {
          title: 'Setup',
          description: 'Initial project setup.',
          estimatedDays: 3,
          dependencies: [],
          acceptanceCriteria: ['Setup completed.'],
          deliverables: ['Repo configured.'],
          percentage: 100,
          budgetAllocation: 500000,
          releaseConditions: ['Ready.'],
          githubAuditRequirements: ['package.json'],
        }
      ],
      tasks: [
        {
          title: 'Setup repository',
          description: 'Setup git repository and build pipeline.',
          estimatedHours: 4,
          priority: 'high',
          acceptanceCriteria: ['Pipelines green.'],
          githubAuditRequirements: ['package.json'],
        }
      ],
      acceptanceCriteria: ['All tests pass.'],
      dependencies: ['Cloud provider'],
      riskAnalysis: [
        {
          description: 'API limit.',
          severity: 'medium',
          mitigation: 'Caching.',
        }
      ],
      timelineEstimates: {
        optimisticDays: 2,
        realisticDays: 3,
        conservativeDays: 5,
        summary: 'Timeline summary.',
      },
      deploymentStrategy: 'Deploy on railway.',
      testingStrategy: 'Vitest unit tests.',
    };

    vi.mocked(axios.post)
      .mockRejectedValueOnce(new Error('Rate limit exceeded'))
      .mockResolvedValueOnce({
        data: {
          choices: [
            {
              message: {
                content: JSON.stringify(validPlanOutput),
              },
            },
          ],
        },
      });

    const { generateProjectPlanWithNemotron } = await import('../../src/services/nemotron.service');

    const plan = await generateProjectPlanWithNemotron(
      'Build a decentralized web storefront',
      500000
    );

    expect(plan.executiveSummary).toBe(validPlanOutput.executiveSummary);
    expect(axios.post).toHaveBeenCalledTimes(2);
  });

  it('should throw an error after max attempts have failed', async () => {
    vi.doMock('../../src/config/env', () => ({
      env: {
        NODE_ENV: 'test',
        NVIDIA_API_KEY: 'nvapi-valid-real-key',
        PLANNER_MODEL: 'nvidia/llama-3.3-nemotron-super-49b-v1',
      },
    }));

    vi.mocked(axios.post).mockRejectedValue(new Error('NVIDIA API is down'));

    const { generateProjectPlanWithNemotron } = await import('../../src/services/nemotron.service');

    await expect(
      generateProjectPlanWithNemotron('Build a decentralized web storefront', 500000)
    ).rejects.toThrow('NVIDIA Nemotron generation failed permanently: NVIDIA API is down');

    expect(axios.post).toHaveBeenCalledTimes(2);
  });
});
