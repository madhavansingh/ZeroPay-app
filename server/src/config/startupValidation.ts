import { env } from './env';

/**
 * Validates the startup environment configuration.
 * Throws an error or terminates the process if invalid settings are detected.
 */
export function validateStartup(): void {
  console.log('🔍 Running system startup validations...');

  const errors: string[] = [];
  const warnings: string[] = [];

  // 1. Guard against developer bypass in production
  if (env.NODE_ENV === 'production') {
    if (env.DEV_AUTH_ENABLED) {
      errors.push('CRITICAL: DEV_AUTH_ENABLED must be false in production mode. Developer auth bypass is prohibited.');
    }

    // 2. Reject mock/placeholder Gemini keys in production
    const geminiKey = env.GEMINI_API_KEY;
    if (geminiKey.startsWith('mock-') || geminiKey.startsWith('test-') || geminiKey.startsWith('AQ.')) {
      errors.push('CRITICAL: GEMINI_API_KEY cannot be a mock, test, or placeholder key (e.g. starting with AQ.) in production.');
    }

    // 3. Reject default admin password in production
    if (env.ADMIN_PASSWORD === 'changeme-in-production') {
      errors.push('CRITICAL: ADMIN_PASSWORD cannot be left as "changeme-in-production" in production.');
    }

    // 4. Validate Firebase key format
    if (env.FIREBASE_PRIVATE_KEY.includes('your-private-key') || env.FIREBASE_PRIVATE_KEY.includes('placeholder')) {
      errors.push('CRITICAL: FIREBASE_PRIVATE_KEY contains placeholder text.');
    }

    // 5. Verify MONGODB_URI is not local or placeholder
    if (env.MONGODB_URI.includes('localhost') || env.MONGODB_URI.includes('127.0.0.1')) {
      warnings.push('WARNING: MONGODB_URI points to local database in production. Ensure this is intentional.');
    }
  }

  // General placeholder checks (applicable in all environments but critical in production)
  const placeholderPatterns = [/placeholder/i, /your-/i, /todo/i, /changeme/i];
  
  // Inspect crucial keys
  const keysToVerify: Array<{ name: keyof typeof env; label: string }> = [
    { name: 'MONGODB_URI', label: 'MongoDB Connection String' },
    { name: 'FIREBASE_PROJECT_ID', label: 'Firebase Project ID' },
    { name: 'FIREBASE_CLIENT_EMAIL', label: 'Firebase Client Email' },
    { name: 'UPSTASH_REDIS_REST_URL', label: 'Upstash Redis REST URL' },
    { name: 'UPSTASH_REDIS_REST_TOKEN', label: 'Upstash Redis REST Token' },
    { name: 'UPSTASH_REDIS_TLS_URL', label: 'Upstash Redis TLS URL' },
    { name: 'BLOCKFROST_PROJECT_ID', label: 'Blockfrost Project ID' },
    { name: 'PINATA_API_KEY', label: 'Pinata API Key' },
    { name: 'PINATA_SECRET_KEY', label: 'Pinata Secret Key' },
    { name: 'PINATA_JWT', label: 'Pinata JWT' },
    { name: 'GEMINI_API_KEY', label: 'Gemini API Key' },
  ];

  for (const item of keysToVerify) {
    const value = String(env[item.name]);
    
    // Check if empty
    if (!value || value.trim() === '') {
      errors.push(`CRITICAL: Environment variable ${String(item.name)} (${item.label}) is empty.`);
      continue;
    }

    // Check against placeholder patterns
    const match = placeholderPatterns.find((pattern) => pattern.test(value));
    if (match) {
      const msg = `CRITICAL: Environment variable ${String(item.name)} (${item.label}) contains placeholder value: "${value}".`;
      if (env.NODE_ENV === 'production') {
        errors.push(msg);
      } else {
        warnings.push(`[Dev Warning] ${msg}`);
      }
    }
  }

  // Print warnings
  if (warnings.length > 0) {
    console.warn('\n⚠️ Startup Validation Warnings:');
    warnings.forEach((w) => console.warn(`  - ${w}`));
  }

  // Fail fast on errors
  if (errors.length > 0) {
    console.error('\n❌ Startup Validation FAILED:');
    errors.forEach((e) => console.error(`  - ${e}`));
    console.error('\nServer startup aborted due to configuration errors.\n');
    process.exit(1);
  }

  console.log('✅ Startup validations passed successfully.\n');
}
