'use strict';

/**
 * Migration: Add core performance indexes
 * 
 * Adds compound and unique indexes required for:
 * - Dashboard aggregation queries (merchantId + status + createdAt)
 * - Invoice lookup by ID and txHash
 * - User lookup by firebaseUid and phone
 * - Merchant lookup by userId and merchantId
 * - Transaction lookup by txHash
 */

async function ensureIndex(collection, keys, options) {
  const name = options.name || Object.keys(keys).map(k => `${k}_${keys[k]}`).join('_');
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
    // ── Invoice indexes ────────────────────────────────────────────────────────
    const invoices = db.collection('invoices');
    await ensureIndex(invoices, { merchantId: 1, createdAt: -1 }, { name: 'merchant_recent' });
    await ensureIndex(invoices, { merchantId: 1, status: 1, settledAt: -1 }, { name: 'merchant_status_settled' });
    await ensureIndex(invoices, { invoiceId: 1 }, { unique: true, name: 'invoiceId_unique' });
    await ensureIndex(invoices, { txHash: 1 }, { sparse: true, unique: true, name: 'txHash_sparse_unique' });
    await ensureIndex(invoices, { customerId: 1, createdAt: -1 }, { name: 'customer_recent' });
    await ensureIndex(invoices, { status: 1, expiresAt: 1 }, { name: 'expiry_sweep' });

    // ── User indexes ───────────────────────────────────────────────────────────
    const users = db.collection('users');
    await ensureIndex(users, { firebaseUid: 1 }, { unique: true, name: 'firebaseUid_unique' });
    await ensureIndex(users, { phone: 1 }, { unique: true, sparse: true, name: 'phone_unique' });

    // ── Merchant indexes ───────────────────────────────────────────────────────
    const merchants = db.collection('merchants');
    await ensureIndex(merchants, { userId: 1 }, { unique: true, name: 'userId_unique' });
    await ensureIndex(merchants, { merchantId: 1 }, { unique: true, name: 'merchantId_unique' });
    await ensureIndex(merchants, { merchantStringId: 1 }, { unique: true, sparse: true, name: 'merchantStringId_unique' });

    // ── Transaction indexes ────────────────────────────────────────────────────
    const transactions = db.collection('transactions');
    await ensureIndex(transactions, { txHash: 1 }, { unique: true, name: 'txHash_unique' });
    await ensureIndex(transactions, { invoiceId: 1 }, { name: 'invoiceId' });
    await ensureIndex(transactions, { status: 1, createdAt: -1 }, { name: 'status_recent' });

    console.log('✅ Core indexes check complete');
  },

  async down(db) {
    const invoices = db.collection('invoices');
    await invoices.dropIndex('merchant_recent').catch(() => {});
    await invoices.dropIndex('merchant_status_settled').catch(() => {});
    await invoices.dropIndex('invoiceId_unique').catch(() => {});
    await invoices.dropIndex('txHash_sparse_unique').catch(() => {});
    await invoices.dropIndex('customer_recent').catch(() => {});
    await invoices.dropIndex('expiry_sweep').catch(() => {});

    const users = db.collection('users');
    await users.dropIndex('firebaseUid_unique').catch(() => {});
    await users.dropIndex('phone_unique').catch(() => {});

    const merchants = db.collection('merchants');
    await merchants.dropIndex('userId_unique').catch(() => {});
    await merchants.dropIndex('merchantId_unique').catch(() => {});
    await merchants.dropIndex('merchantStringId_unique').catch(() => {});

    const transactions = db.collection('transactions');
    await transactions.dropIndex('txHash_unique').catch(() => {});
    await transactions.dropIndex('invoiceId').catch(() => {});
    await transactions.dropIndex('status_recent').catch(() => {});

    console.log('✅ Core indexes removed (rollback)');
  },
};
