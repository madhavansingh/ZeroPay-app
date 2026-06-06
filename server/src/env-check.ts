import 'dotenv/config';
import mongoose from 'mongoose';
import Redis from 'ioredis';
import { initializeApp, cert, deleteApp } from 'firebase-admin/app';
import { getDatabase } from 'firebase-admin/database';
import axios from 'axios';

async function checkMongo(uri: string) {
  console.log('⏳ Connecting to MongoDB Atlas...');
  try {
    const start = Date.now();
    await mongoose.connect(uri, { serverSelectionTimeoutMS: 5000 });
    console.log(`✅ MongoDB connection successful (latency: ${Date.now() - start}ms)`);
    await mongoose.disconnect();
  } catch (err: any) {
    console.error('❌ MongoDB connection failed:', err.message);
  }
}

async function checkUpstashTls(url: string) {
  console.log('⏳ Connecting to Upstash Redis TLS (ioredis)...');
  try {
    const start = Date.now();
    const client = new Redis(url, { maxRetriesPerRequest: 1, connectTimeout: 5000 });
    const pong = await client.ping();
    console.log(`✅ Upstash Redis TLS (BullMQ connection) successful: ${pong} (latency: ${Date.now() - start}ms)`);
    client.disconnect();
  } catch (err: any) {
    console.error('❌ Upstash Redis TLS connection failed:', err.message);
  }
}

async function checkUpstashRest(url: string, token: string) {
  console.log('⏳ Querying Upstash Redis REST API...');
  try {
    const start = Date.now();
    const res = await axios.get(`${url}/ping`, {
      headers: { Authorization: `Bearer ${token}` },
      timeout: 5000,
    });
    console.log(`✅ Upstash Redis REST query successful: ${res.data.result} (latency: ${Date.now() - start}ms)`);
  } catch (err: any) {
    console.error('❌ Upstash Redis REST query failed:', err.message);
  }
}

async function checkFirebase(projectId: string, clientEmail: string, privateKey: string, dbUrl: string) {
  console.log('⏳ Initializing Firebase Admin SDK...');
  try {
    const start = Date.now();
    const app = initializeApp({
      credential: cert({
        projectId,
        clientEmail,
        privateKey: privateKey.replace(/\\n/g, '\n'),
      }),
      databaseURL: dbUrl,
    });
    const db = getDatabase(app);
    const ref = db.ref('.info/connected');
    const snapshot = await ref.once('value');
    console.log(`✅ Firebase Admin SDK initialized. DB Connection status: ${snapshot.val()} (latency: ${Date.now() - start}ms)`);
    await deleteApp(app);
  } catch (err: any) {
    console.error('❌ Firebase Admin SDK initialization failed:', err.message);
  }
}

async function checkBlockfrost(projectId: string, network: string) {
  console.log('⏳ Querying Blockfrost Cardano API...');
  try {
    const start = Date.now();
    const baseUrl = network === 'mainnet'
      ? 'https://cardano-mainnet.blockfrost.io/api/v0'
      : `https://cardano-${network}.blockfrost.io/api/v0`;
    const res = await axios.get(`${baseUrl}/health`, {
      headers: { project_id: projectId },
      timeout: 5000,
    });
    console.log(`✅ Blockfrost API query successful: ${JSON.stringify(res.data)} (latency: ${Date.now() - start}ms)`);
  } catch (err: any) {
    console.error('❌ Blockfrost API query failed:', err.message);
  }
}

async function checkPinata(jwt: string) {
  console.log('⏳ Querying Pinata IPFS authentication test...');
  try {
    const start = Date.now();
    const res = await axios.get('https://api.pinata.cloud/data/testAuthentication', {
      headers: { Authorization: `Bearer ${jwt}` },
      timeout: 5000,
    });
    console.log(`✅ Pinata IPFS auth query successful: ${JSON.stringify(res.data)} (latency: ${Date.now() - start}ms)`);
  } catch (err: any) {
    console.error('❌ Pinata IPFS auth query failed:', err.message);
  }
}

async function main() {
  console.log('\n======================================================');
  console.log('🔍 ZEROPAY ENVIRONMENT RESILIENCY & SERVICE CHECK');
  console.log('======================================================\n');

  const mongoUri = process.env.MONGODB_URI;
  const redisTls = process.env.UPSTASH_REDIS_TLS_URL;
  const redisRestUrl = process.env.UPSTASH_REDIS_REST_URL;
  const redisRestToken = process.env.UPSTASH_REDIS_REST_TOKEN;
  
  const fbProject = process.env.FIREBASE_PROJECT_ID;
  const fbEmail = process.env.FIREBASE_CLIENT_EMAIL;
  const fbKey = process.env.FIREBASE_PRIVATE_KEY;
  const fbDbUrl = process.env.FIREBASE_DATABASE_URL;

  const bfProject = process.env.BLOCKFROST_PROJECT_ID;
  const bfNetwork = process.env.BLOCKFROST_NETWORK;

  const pinataJwt = process.env.PINATA_JWT;

  if (mongoUri) {
    await checkMongo(mongoUri);
  } else {
    console.error('❌ MONGODB_URI missing.');
  }

  if (redisTls) {
    await checkUpstashTls(redisTls);
  } else {
    console.error('❌ UPSTASH_REDIS_TLS_URL missing.');
  }

  if (redisRestUrl && redisRestToken) {
    await checkUpstashRest(redisRestUrl, redisRestToken);
  } else {
    console.error('❌ UPSTASH_REDIS_REST_URL or UPSTASH_REDIS_REST_TOKEN missing.');
  }

  if (fbProject && fbEmail && fbKey && fbDbUrl) {
    await checkFirebase(fbProject, fbEmail, fbKey, fbDbUrl);
  } else {
    console.error('❌ Firebase Admin credentials missing.');
  }

  if (bfProject && bfNetwork) {
    await checkBlockfrost(bfProject, bfNetwork);
  } else {
    console.error('❌ Blockfrost project configuration missing.');
  }

  if (pinataJwt) {
    await checkPinata(pinataJwt);
  } else {
    console.error('❌ PINATA_JWT missing.');
  }

  console.log('\n======================================================');
  console.log('🏁 SERVICE CHECK COMPLETE');
  console.log('======================================================\n');
}

main().catch((err) => {
  console.error('Sanity check crashed:', err);
});
