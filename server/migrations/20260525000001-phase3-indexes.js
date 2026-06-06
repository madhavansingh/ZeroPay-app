'use strict';

/**
 * Migration: Add Phase 3 indexes
 * 
 * Adds compound, unique, and text indexes required for:
 * - Products search and category filtering
 * - Reviews verification and invoice constraints
 * - API Key hashed lookups
 * - Webhook subscriptions queries
 * - Dispute verdicts auto-execution tracking
 * - Digital deliveries expiry TTL lookups
 * - Merchant storefront unique slug indexing and location filters
 */

async function ensureIndex(collection, keys, options = {}) {
  const name = options.name || Object.keys(keys).map(k => `${k.replace(/\./g, '_')}_${keys[k]}`).join('_');
  const collectionName = collection.collectionName;

  try {
    const existingIndexes = await collection.indexes().catch(() => []);

    const serializeKeys = (keyObj) => {
      return Object.entries(keyObj)
        .map(([k, v]) => `${k}:${v}`)
        .join(',');
    };

    const targetKeysStr = serializeKeys(keys);
    const matchingKeyIndex = existingIndexes.find(idx => serializeKeys(idx.key) === targetKeysStr);

    if (matchingKeyIndex) {
      if (matchingKeyIndex.name === name) {
        console.log(`[Index] Index "${name}" already exists on "${collectionName}". Skipping.`);
      } else {
        console.log(`[Index] Index with keys ${JSON.stringify(keys)} already exists on "${collectionName}" with name "${matchingKeyIndex.name}". Skipping to prevent collision.`);
      }
      return;
    }

    const matchingNameIndex = existingIndexes.find(idx => idx.name === name);
    if (matchingNameIndex) {
      console.warn(`[Index] WARNING: Index name "${name}" already exists on "${collectionName}" but with different keys. Appending suffix to prevent failure.`);
      options.name = `${name}_new`;
    }

    await collection.createIndex(keys, options);
    console.log(`[Index] Created index "${options.name || name}" on "${collectionName}".`);
  } catch (err) {
    console.error(`[Index] Failed to ensure index "${name}" on "${collectionName}":`, err.message);
  }
}

module.exports = {
  async up(db) {
    // ── Products indexes ───────────────────────────────────────────────────────
    const products = db.collection('products');
    await ensureIndex(products, { merchantId: 1, isActive: 1, category: 1 }, { name: 'merchant_active_category' });
    await ensureIndex(products, { title: 'text', description: 'text', tags: 'text' }, { name: 'products_text_search' });

    // ── Reviews indexes ────────────────────────────────────────────────────────
    const reviews = db.collection('reviews');
    await ensureIndex(reviews, { merchantId: 1, isVerified: 1 }, { name: 'merchant_verified_reviews' });
    await ensureIndex(reviews, { invoiceId: 1 }, { unique: true, name: 'invoiceId_review_unique' });

    // ── API Keys indexes ───────────────────────────────────────────────────────
    const apiKeys = db.collection('apikeys'); // Mongoose defaults collection name to lowercase plural
    await ensureIndex(apiKeys, { keyHash: 1 }, { unique: true, name: 'keyHash_unique' });
    await ensureIndex(apiKeys, { merchantId: 1, isActive: 1 }, { name: 'merchant_active_keys' });

    // ── Webhook Subscriptions indexes ──────────────────────────────────────────
    const webhookSubscriptions = db.collection('webhooksubscriptions');
    await ensureIndex(webhookSubscriptions, { merchantId: 1, isActive: 1 }, { name: 'merchant_active_webhooks' });

    // ── Dispute Verdicts indexes ────────────────────────────────────────────────
    const disputeVerdicts = db.collection('disputeverdicts');
    await ensureIndex(disputeVerdicts, { invoiceId: 1 }, { unique: true, name: 'invoiceId_verdict_unique' });
    await ensureIndex(disputeVerdicts, { status: 1, autoExecAt: 1 }, { name: 'verdicts_auto_execution' });

    // ── Digital Deliveries indexes ─────────────────────────────────────────────
    const digitalDeliveries = db.collection('digitaldeliveries');
    await ensureIndex(digitalDeliveries, { invoiceId: 1 }, { name: 'invoiceId_delivery' });
    await ensureIndex(digitalDeliveries, { expiresAt: 1 }, { name: 'expiresAt_ttl' });

    // ── Merchant slug + location indexes ───────────────────────────────────────
    const merchants = db.collection('merchants');
    await ensureIndex(merchants, { slug: 1 }, { unique: true, sparse: true, name: 'slug_unique_sparse' });
    await ensureIndex(merchants, { 'location.city': 1 }, { sparse: true, name: 'location_city' });

    console.log('✅ Phase 3 indexes check complete');
  },

  async down(db) {
    const products = db.collection('products');
    await products.dropIndex('merchant_active_category').catch(() => {});
    await products.dropIndex('products_text_search').catch(() => {});

    const reviews = db.collection('reviews');
    await reviews.dropIndex('merchant_verified_reviews').catch(() => {});
    await reviews.dropIndex('invoiceId_review_unique').catch(() => {});

    const apiKeys = db.collection('apikeys');
    await apiKeys.dropIndex('keyHash_unique').catch(() => {});
    await apiKeys.dropIndex('merchant_active_keys').catch(() => {});

    const webhookSubscriptions = db.collection('webhooksubscriptions');
    await webhookSubscriptions.dropIndex('merchant_active_webhooks').catch(() => {});

    const disputeVerdicts = db.collection('disputeverdicts');
    await disputeVerdicts.dropIndex('invoiceId_verdict_unique').catch(() => {});
    await disputeVerdicts.dropIndex('verdicts_auto_execution').catch(() => {});

    const digitalDeliveries = db.collection('digitaldeliveries');
    await digitalDeliveries.dropIndex('invoiceId_delivery').catch(() => {});
    await digitalDeliveries.dropIndex('expiresAt_ttl').catch(() => {});

    const merchants = db.collection('merchants');
    await merchants.dropIndex('slug_unique_sparse').catch(() => {});
    await merchants.dropIndex('location_city').catch(() => {});

    console.log('✅ Phase 3 indexes removed (rollback)');
  },
};
