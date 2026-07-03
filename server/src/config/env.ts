import { z } from 'zod';
import path from 'path';
import dotenv from 'dotenv';

// Ensure environment variables are loaded from process.cwd() or repository root
dotenv.config();
dotenv.config({ path: path.resolve(__dirname, '../../../.env') });

const envSchema = z.object({
  // Server
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  PORT: z.string().default('4000').transform(Number),

  // MongoDB
  MONGODB_URI: z.string().min(1, 'MONGODB_URI is required'),

  // Firebase Admin
  FIREBASE_PROJECT_ID: z.string().min(1, 'FIREBASE_PROJECT_ID is required'),
  FIREBASE_PRIVATE_KEY: z.string().min(1, 'FIREBASE_PRIVATE_KEY is required'),
  FIREBASE_CLIENT_EMAIL: z.string().email('FIREBASE_CLIENT_EMAIL must be valid'),
  FIREBASE_DATABASE_URL: z.string().url('FIREBASE_DATABASE_URL must be a valid URL'),

  // Upstash Redis (HTTP — for caching)
  UPSTASH_REDIS_REST_URL: z.string().url('UPSTASH_REDIS_REST_URL must be a valid URL'),
  UPSTASH_REDIS_REST_TOKEN: z.string().min(1, 'UPSTASH_REDIS_REST_TOKEN is required'),

  // Upstash Redis (TLS ioredis — for BullMQ)
  UPSTASH_REDIS_TLS_URL: z.string().min(1, 'UPSTASH_REDIS_TLS_URL is required'),

  // Blockfrost
  BLOCKFROST_PROJECT_ID: z.string().min(1, 'BLOCKFROST_PROJECT_ID is required'),
  BLOCKFROST_NETWORK: z.enum(['mainnet', 'preprod', 'preview']).default('preprod'),

  // Pinata IPFS
  PINATA_API_KEY: z.string().min(1, 'PINATA_API_KEY is required'),
  PINATA_SECRET_KEY: z.string().min(1, 'PINATA_SECRET_KEY is required'),
  PINATA_JWT: z.string().min(1, 'PINATA_JWT is required'),

  // CORS
  ALLOWED_ORIGINS: z.string().default('http://localhost:5173'),

  // App
  MERCHANT_ID_PREFIX: z.string().default('MC'),
  MIN_CONFIRMATIONS: z.string().default('3').transform(Number),
  HIGH_VALUE_THRESHOLD_USD: z.string().default('500').transform(Number),
  HIGH_VALUE_CONFIRMATIONS: z.string().default('6').transform(Number),
  INVOICE_EXPIRY_DEFAULT_SECONDS: z.string().default('600').transform(Number),

  // Admin UI (Bull Board)
  ADMIN_USERNAME: z.string().default('zeropay-admin'),
  ADMIN_PASSWORD: z.string().default('changeme-in-production'),

  // Sentry (optional)
  SENTRY_DSN: z.string().url().optional(),

  // Gemini API
  GEMINI_API_KEY: z.string().min(1, 'GEMINI_API_KEY is required'),

  // NVIDIA API
  NVIDIA_API_KEY: z.string().min(1, 'NVIDIA_API_KEY is required'),
  PLANNER_MODEL: z.string().default('nvidia/llama-3.3-nemotron-super-49b-v1'),

  // Repository Audit Limits
  AUDIT_MAX_COMMITS: z.string().default('100').transform(Number),
  AUDIT_MAX_PULL_REQUESTS: z.string().default('50').transform(Number),
  AUDIT_MAX_FILES: z.string().default('1000').transform(Number),
  AUDIT_MAX_WORKFLOW_RUNS: z.string().default('25').transform(Number),

  // Escrow configuration
  ESCROW_ADMIN_ADDRESS: z.string().regex(/^addr(_test)?1[a-z0-9]+$/).default('addr_test1vqg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zygxrcya6'),
  ESCROW_TREASURY_ADDRESS: z.string().regex(/^addr(_test)?1[a-z0-9]+$/).default('addr_test1vq3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zygswahgq5'),
  ESCROW_PLATFORM_FEE_LOVELACE: z.string().default('2000000').transform(Number),

  // Dev Mode Auth Bypass Configuration
  DEV_AUTH_ENABLED: z.preprocess((val) => val === 'true' || val === true, z.boolean()).default(false),

  // Workflows API Base URL
  WORKFLOW_API_BASE_URL: z.string().url('WORKFLOW_API_BASE_URL must be a valid URL').default('http://localhost:4000/api/v1'),

  // GitHub token (optional)
  GITHUB_TOKEN: z.string().optional(),
}).superRefine((data, ctx) => {
  if (data.NODE_ENV === 'production') {
    const isPlaceholderGemini = /placeholder|your_|your-|todo|changeme|mock-gemini|test-key/i.test(data.GEMINI_API_KEY) || data.GEMINI_API_KEY.trim() === '';
    if (isPlaceholderGemini) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'GEMINI_API_KEY cannot be a placeholder, mock, or test key in production mode',
        path: ['GEMINI_API_KEY'],
      });
    }
    const isPlaceholderNvidia = /placeholder|your_|your-|todo|changeme|mock-nvidia|test-key/i.test(data.NVIDIA_API_KEY) || data.NVIDIA_API_KEY.trim() === '';
    if (isPlaceholderNvidia) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'NVIDIA_API_KEY cannot be a placeholder, mock, or test key in production mode',
        path: ['NVIDIA_API_KEY'],
      });
    }
    const isInsecureAdminPass = /changeme|admin|password|12345/i.test(data.ADMIN_PASSWORD) || data.ADMIN_PASSWORD.trim() === '';
    if (isInsecureAdminPass) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'ADMIN_PASSWORD must be explicitly set to a secure secret in production mode',
        path: ['ADMIN_PASSWORD'],
      });
    }
  }
});

const parsed = envSchema.safeParse(process.env);

if (!parsed.success) {
  console.error('❌ Invalid environment variables:');
  console.error(parsed.error.flatten().fieldErrors);
  process.exit(1);
}

export const env = parsed.data;
export type Env = typeof env;
