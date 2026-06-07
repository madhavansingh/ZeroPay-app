import axios from 'axios';
import { env } from '../config/env';
import { logger } from '../config/logger';
import { nemotronProjectPlanSchema, NemotronProjectPlanInput } from '../schemas/projectPlan.schema';

const isMockMode = env.NVIDIA_API_KEY.startsWith('mock-');

const SYSTEM_PROMPT = `You are ZeroPay Project Architect.
Convert rough user ideas into production-grade software execution plans.
The user may provide only a short sentence.
Infer missing requirements intelligently.
Generate complete implementation plans suitable for real engineering teams.

You MUST produce a single structured JSON object conforming strictly to the requested schema.
Do NOT return markdown code blocks.
Do NOT return any explanations, conversational text, or preface before or after the JSON.
Your entire output must be parseable as a valid JSON object.

The required JSON structure is:
{
  "executiveSummary": "A clear overview of the project scope and deliverables.",
  "productVision": "The long-term vision and goal of the product.",
  "functionalRequirements": ["Requirement 1 description", "Requirement 2 description"],
  "nonFunctionalRequirements": ["Performance target", "Security target"],
  "systemArchitecture": "Detailed description of the technology stack, components, and communication flow.",
  "databaseDesign": "Detailed description of tables, schemas, relations, and data stores.",
  "apiDesign": "Detailed description of API endpoints, request/response formats, and protocols.",
  "milestones": [
    {
      "title": "Milestone title",
      "description": "Milestone description",
      "estimatedDays": 5,
      "dependencies": [],
      "acceptanceCriteria": ["Criteria 1", "Criteria 2"],
      "deliverables": ["Deliverable 1", "Deliverable 2"],
      "percentage": 25,
      "budgetAllocation": 125000,
      "releaseConditions": ["Condition 1", "Condition 2"],
      "githubAuditRequirements": ["file1.ts", "feature test 1"]
    }
  ],
  "tasks": [
    {
      "title": "Task title",
      "description": "Detailed description",
      "estimatedHours": 8,
      "priority": "medium",
      "acceptanceCriteria": ["Criteria 1"],
      "githubAuditRequirements": ["file1.ts"]
    }
  ],
  "acceptanceCriteria": ["Overall criteria 1", "Overall criteria 2"],
  "dependencies": ["External API dependency"],
  "riskAnalysis": [
    {
      "description": "Potential risk description",
      "severity": "medium",
      "mitigation": "Mitigation strategy"
    }
  ],
  "timelineEstimates": {
    "optimisticDays": 10,
    "realisticDays": 15,
    "conservativeDays": 20,
    "summary": "Detailed timeline description"
  },
  "deploymentStrategy": "Step-by-step production deployment strategy.",
  "testingStrategy": "Unit testing, integration testing, and E2E verification plan."
}`;

/**
 * Attempts to repair common JSON malformations from LLM outputs.
 */
function attemptJSONRepair(content: string): string {
  let cleaned = content.trim();
  // Strip markdown code blocks if present
  if (cleaned.startsWith('```')) {
    cleaned = cleaned.replace(/^```(json)?\n?/, '').replace(/\n?```$/, '').trim();
  }
  return cleaned;
}

/**
 * Generates a high-quality mock project plan that conforms perfectly to the Zod schema.
 */
function generateMockPlan(requirements: string, totalAmountPaise: number): NemotronProjectPlanInput {
  const halfBudget = Math.floor(totalAmountPaise / 2);
  const remainingBudget = totalAmountPaise - halfBudget;

  return {
    executiveSummary: `Mock implementation plan for: "${requirements}". This blueprint outlines the development stages, system architecture, and quality controls.`,
    productVision: `To deliver a robust, enterprise-grade solution that solves: "${requirements}" utilizing modern technology.`,
    functionalRequirements: [
      'User registration and secure authentication system.',
      'Core business logic processing engine.',
      'Real-time transaction tracking and operational dashboard.',
    ],
    nonFunctionalRequirements: [
      'Latency of less than 200ms for API response times.',
      '99.9% uptime availability of service.',
      'Complete end-to-end encryption for all sensitive fields.',
    ],
    systemArchitecture: 'React/Flutter frontend communicating with a Node.js/TypeScript backend deployed on AWS/Railway, persisting to MongoDB.',
    databaseDesign: 'User and Transaction schemas defined in Mongoose, with indexes on critical query fields.',
    apiDesign: 'REST API endpoints including POST /auth/login, GET /transactions, and POST /escrow/lock.',
    milestones: [
      {
        title: 'Initial Scaffolding and DB Setup',
        description: 'Set up database schemas, configurations, and core authentication mechanisms.',
        estimatedDays: 5,
        dependencies: [],
        acceptanceCriteria: ['Database connection is stable', 'Auth endpoints return valid JWT tokens'],
        deliverables: ['Mongoose model files', 'JWT auth middleware'],
        percentage: 50,
        budgetAllocation: halfBudget,
        releaseConditions: ['Database models verified', 'Auth tests passing'],
        githubAuditRequirements: ['server/src/models/User.ts', 'server/src/middleware/auth.ts'],
      },
      {
        title: 'Core Business Logic and Handover',
        description: 'Implement core application features, webhook integrations, and deploy to staging.',
        estimatedDays: 7,
        dependencies: ['Initial Scaffolding and DB Setup'],
        acceptanceCriteria: ['All business endpoints functional', 'Staging deployment runs successfully'],
        deliverables: ['API route files', 'Staging Dockerfile'],
        percentage: 50,
        budgetAllocation: remainingBudget,
        releaseConditions: ['Staging deployment live', 'Integration test suite passing'],
        githubAuditRequirements: ['server/src/routes/api.routes.ts', 'Dockerfile'],
      },
    ],
    tasks: [
      {
        title: 'Define MongoDB Mongoose Schema',
        description: 'Create user database tables with secure encrypted fields.',
        estimatedHours: 6,
        priority: 'high',
        acceptanceCriteria: ['Models validate correctly', 'Index creation verified'],
        githubAuditRequirements: ['server/src/models/User.ts'],
      },
      {
        title: 'Implement JWT Auth Middleware',
        description: 'Write auth validation filters that intercept incoming requests.',
        estimatedHours: 8,
        priority: 'high',
        acceptanceCriteria: ['Valid tokens pass', 'Malformed tokens rejected'],
        githubAuditRequirements: ['server/src/middleware/auth.ts'],
      },
      {
        title: 'Configure Staging Deployment',
        description: 'Write Dockerfile and setting configurations for Railway runtime.',
        estimatedHours: 10,
        priority: 'medium',
        acceptanceCriteria: ['Container builds locally and runs without errors'],
        githubAuditRequirements: ['Dockerfile'],
      },
    ],
    acceptanceCriteria: [
      'All integration tests run and pass without errors.',
      'Deployment to staging is verified and fully functional.',
    ],
    dependencies: [
      'NVIDIA integrate API access.',
      'MongoDB Atlas cluster configuration.',
    ],
    riskAnalysis: [
      {
        description: 'Token limit exhausted on LLM service.',
        severity: 'medium',
        mitigation: 'Implement caching of static query blueprints.',
      },
    ],
    timelineEstimates: {
      optimisticDays: 8,
      realisticDays: 12,
      conservativeDays: 18,
      summary: 'Requires approximately 2 weeks of engineering time based on 3 milestones.',
    },
    deploymentStrategy: 'Deploy using Docker containers on Railway, connected to MongoDB Atlas.',
    testingStrategy: 'Vitest unit tests, Playwright end-to-end integration tests.',
  };
}

/**
 * Direct NVIDIA Nemotron project plan generator.
 */
export async function generateProjectPlanWithNemotron(
  requirements: string,
  totalAmountPaise: number
): Promise<NemotronProjectPlanInput> {
  const startTime = Date.now();
  logger.info(`[Nemotron Service] Initiating project plan generation for prompt: "${requirements}"`);

  if (isMockMode) {
    logger.info('[Nemotron Service] Running in MOCK mode. Generating mock plan.');
    return generateMockPlan(requirements, totalAmountPaise);
  }

  const userPrompt = `Generate a detailed software execution plan for:
Requirements: "${requirements}"
Total Budget: ${totalAmountPaise} Paise.

Ensure the milestone percentages sum to exactly 100%, and the sum of milestone budget allocations equals ${totalAmountPaise} exactly.`;

  let attempt = 0;
  const maxAttempts = 2; // initial try + 1 retry

  while (attempt < maxAttempts) {
    attempt++;
    try {
      const response = await axios.post(
        'https://integrate.api.nvidia.com/v1/chat/completions',
        {
          model: env.PLANNER_MODEL,
          messages: [
            { role: 'system', content: SYSTEM_PROMPT },
            { role: 'user', content: userPrompt },
          ],
          temperature: 0.2,
          max_tokens: 4096,
        },
        {
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${env.NVIDIA_API_KEY}`,
          },
          timeout: 60000, // 60s timeout for large plans
        }
      );

      const content = response.data?.choices?.[0]?.message?.content;
      if (!content) {
        throw new Error('NVIDIA API returned an empty completion.');
      }

      // Attempt repair once
      const repairedContent = attemptJSONRepair(content);
      const parsedJSON = JSON.parse(repairedContent);

      // Validate schema
      const result = nemotronProjectPlanSchema.safeParse(parsedJSON);
      if (!result.success) {
        throw new Error(`Zod validation failed: ${JSON.stringify(result.error.flatten())}`);
      }

      logger.info(`[Nemotron Service] Plan successfully generated and validated in ${Date.now() - startTime}ms (Attempt ${attempt}).`);
      return result.data;
    } catch (err: any) {
      logger.warn(`[Nemotron Service] Attempt ${attempt} failed: ${err.message}`);
      if (attempt >= maxAttempts) {
        logger.error(`[Nemotron Service] Planning engine failed permanently after ${attempt} attempts.`);
        throw new Error(`NVIDIA Nemotron generation failed permanently: ${err.message}`);
      }
      logger.info('[Nemotron Service] Retrying generation...');
    }
  }

  throw new Error('NVIDIA Nemotron generation reached an unreachable code path.');
}
