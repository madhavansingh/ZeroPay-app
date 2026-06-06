import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { requireAuth } from '../middleware/auth';
import { validate } from '../middleware/validate';
import { getFirebaseDatabase } from '../config/firebase-admin';
import { Merchant } from '../models/Merchant';
import { runNegotiationStep } from '../services/agent/negotiationAgent';

const router = Router();

// ─── POST /chat/rooms/create ─────────────────────────────────────────────────
const createRoomSchema = z.object({
  merchantStringId: z.string().min(1),
});

router.post(
  '/rooms/create',
  requireAuth,
  validate(createRoomSchema),
  async (req: Request, res: Response): Promise<void> => {
    const { merchantStringId } = req.body as { merchantStringId: string };
    const customerId = req.user._id.toString();

    const merchant = await Merchant.findOne({ merchantId: merchantStringId });
    if (!merchant) {
      res.status(404).json({ success: false, error: 'Merchant not found' });
      return;
    }

    const roomId = `${customerId}-${merchantStringId}`;
    const db = getFirebaseDatabase();
    const existing = await db.ref(`/chatrooms/${roomId}`).get();

    if (!existing.exists()) {
      const now = Date.now();

      await db.ref(`/chatrooms/${roomId}`).set({
        roomId,
        merchantId: merchantStringId,
        customerId,
        shopName: merchant.shopName,
        merchantMongoId: merchant._id.toString(),
        createdAt: now,
        lastMessage: null,
      });

      // Index rooms under each participant so frontend can query fast
      await Promise.all([
        db.ref(`/users/${customerId}/chatrooms/${roomId}`).set({
          roomId,
          merchantId: merchantStringId,
          shopName: merchant.shopName,
          lastMessage: null,
          unreadCount: 0,
        }),
        db.ref(`/users/${merchant._id.toString()}/chatrooms/${roomId}`).set({
          roomId,
          customerId,
          shopName: merchant.shopName,
          lastMessage: null,
          unreadCount: 0,
        }),
      ]);
    }

    res.json({
      success: true,
      data: {
        roomId,
        merchantStringId,
        shopName: merchant.shopName,
        isNew: !existing.exists(),
      },
    });
  }
);

// ─── GET /chat/rooms ──────────────────────────────────────────────────────────
router.get('/rooms', requireAuth, async (req: Request, res: Response): Promise<void> => {
  const userId = req.user._id.toString();
  const db = getFirebaseDatabase();
  const snapshot = await db.ref(`/users/${userId}/chatrooms`).get();

  const rooms = snapshot.exists() ? Object.values(snapshot.val() as Record<string, unknown>) : [];

  res.json({ success: true, data: { rooms } });
});

// ─── GET /chat/rooms/:roomId ─────────────────────────────────────────────────
router.get('/rooms/:roomId', requireAuth, async (req: Request, res: Response): Promise<void> => {
  const { roomId } = req.params;
  const db = getFirebaseDatabase();

  const [roomSnap, messagesSnap] = await Promise.all([
    db.ref(`/chatrooms/${roomId}`).get(),
    db.ref(`/chats/${roomId}/messages`).limitToLast(50).get(),
  ]);

  if (!roomSnap.exists()) {
    res.status(404).json({ success: false, error: 'Chat room not found' });
    return;
  }

  const messages = messagesSnap.exists()
    ? Object.entries(messagesSnap.val() as Record<string, unknown>).map(([key, val]) => ({
        key,
        ...(val as object),
      }))
    : [];

  res.json({ success: true, data: { room: roomSnap.val(), messages } });
});

// ─── POST /chat/rooms/:roomId/messages ─────────────────────────────────────────
const sendMessageSchema = z.object({
  invoiceId: z.string().min(1),
  message: z.string().min(1),
});

router.post(
  '/rooms/:roomId/messages',
  requireAuth,
  validate(sendMessageSchema),
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { roomId } = req.params;
      const { invoiceId, message } = req.body as { invoiceId: string; message: string };
      const userId = req.user._id.toString();

      const db = getFirebaseDatabase();

      // 1. Push customer's message to Firebase Chatroom messages node
      const customerMsgRef = db.ref(`/chats/${roomId}/messages`).push();
      const customerMsg = {
        id: customerMsgRef.key,
        senderId: userId,
        type: 'text',
        timestamp: Date.now(),
        payload: { text: message },
      };
      await customerMsgRef.set(customerMsg);

      // Update lastMessage on chatroom
      await db.ref(`/chatrooms/${roomId}`).update({
        lastMessage: {
          preview: message.slice(0, 60),
          timestamp: Date.now(),
        },
      });

      // 2. Trigger AI negotiation agent step
      const aiResult = await runNegotiationStep(invoiceId, message, userId, res.locals.requestId);

      // 3. Push AI agent's response message to Firebase
      const aiMsgRef = db.ref(`/chats/${roomId}/messages`).push();
      const aiMsg = {
        id: aiMsgRef.key,
        senderId: 'zeropay-ai-agent',
        type: 'text',
        timestamp: Date.now(),
        payload: { text: aiResult.responseMessage },
      };
      await aiMsgRef.set(aiMsg);

      // Update lastMessage on chatroom to AI response
      await db.ref(`/chatrooms/${roomId}`).update({
        lastMessage: {
          preview: aiResult.responseMessage.slice(0, 60),
          timestamp: Date.now(),
        },
      });

      res.json({
        success: true,
        data: {
          customerMessage: customerMsg,
          aiResponse: aiMsg,
          dealAgreed: aiResult.dealAgreed,
          proposedPricePaise: aiResult.proposedPricePaise,
        },
      });
    } catch (err) {
      next(err);
    }
  }
);

export default router;
