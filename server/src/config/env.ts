import { z } from 'zod';

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

  // Escrow configuration
  ESCROW_ADMIN_ADDRESS: z.string().regex(/^addr(_test)?1[a-z0-9]+$/).default('addr_test1vqg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zygxrcya6'),
  ESCROW_TREASURY_ADDRESS: z.string().regex(/^addr(_test)?1[a-z0-9]+$/).default('addr_test1vq3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zygswahgq5'),
  ESCROW_PLATFORM_FEE_LOVELACE: z.string().default('2000000').transform(Number),
});

const parsed = envSchema.safeParse(process.env);

if (!parsed.success) {
  console.error('❌ Invalid environment variables:');
  console.error(parsed.error.flatten().fieldErrors);
  process.exit(1);
}

export const env = parsed.data;
export type Env = typeof env;
