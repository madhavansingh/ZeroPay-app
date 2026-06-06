import { getFirebaseMessaging } from '../config/firebase-admin';
import { User } from '../models/User';

export interface NotificationPayload {
  title: string;
  body: string;
  data?: Record<string, string>;
}

export async function sendPushToUser(
  userId: string,
  payload: NotificationPayload
): Promise<void> {
  const user = await User.findById(userId, { fcmToken: 1, notificationPreferences: 1 });
  if (!user?.fcmToken) return;

  try {
    await getFirebaseMessaging().send({
      token: user.fcmToken,
      notification: {
        title: payload.title,
        body: payload.body,
      },
      data: payload.data ?? {},
      android: { priority: 'high' },
      apns: {
        payload: {
          aps: { sound: 'default', badge: 1 },
        },
      },
    });
  } catch (err) {
    // FCM errors are non-fatal — log and continue
    console.warn(`[notification] FCM send failed for user ${userId}:`, err);
  }
}

export async function sendPushToFirebaseUid(
  firebaseUid: string,
  payload: NotificationPayload
): Promise<void> {
  const user = await User.findOne({ firebaseUid }, { fcmToken: 1 });
  if (!user) return;
  await sendPushToUser(user.id as string, payload);
}
