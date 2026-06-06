import * as admin from 'firebase-admin';
import { env } from './env';

let initialized = false;

export function initFirebase(): void {
  if (initialized || admin.apps.length > 0) return;

  admin.initializeApp({
    credential: admin.credential.cert({
      projectId: env.FIREBASE_PROJECT_ID,
      privateKey: env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
      clientEmail: env.FIREBASE_CLIENT_EMAIL,
    }),
    databaseURL: env.FIREBASE_DATABASE_URL,
  });

  initialized = true;
  console.log('✅ Firebase Admin initialized');
}

export function getFirebaseAdmin(): admin.app.App {
  if (!initialized) initFirebase();
  return admin.app();
}

export function getFirebaseAuth(): admin.auth.Auth {
  return admin.auth();
}

export function getFirebaseDatabase(): admin.database.Database {
  return admin.database();
}

export function getFirebaseMessaging(): admin.messaging.Messaging {
  return admin.messaging();
}
