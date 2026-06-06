import { Server as SocketIOServer } from 'socket.io';
import type { Server as HTTPServer } from 'http';
import { createAdapter } from '@socket.io/redis-adapter';
import Redis from 'ioredis';
import { env } from './env';
import { logger } from './logger';

let io: SocketIOServer | null = null;

export function initSocketServer(httpServer: HTTPServer, redisTlsUrl: string): SocketIOServer {
  // Use separate Redis connection for pub/sub adapter as required by socket.io
  const pubClient = new Redis(redisTlsUrl, { maxRetriesPerRequest: null });
  const subClient = pubClient.duplicate();

  io = new SocketIOServer(httpServer, {
    cors: {
      origin: env.ALLOWED_ORIGINS.split(',').map((o) => o.trim()),
      credentials: true,
    },
  });

  io.adapter(createAdapter(pubClient, subClient));

  io.on('connection', (socket) => {
    logger.info('[socket] Client connected', { socketId: socket.id });

    // Join Rooms
    socket.on('join:merchant', (merchantId: string) => {
      socket.join(`merchant:${merchantId}`);
      logger.debug('[socket] Client joined merchant room', { socketId: socket.id, merchantId });
    });

    socket.on('join:invoice', (invoiceId: string) => {
      socket.join(`invoice:${invoiceId}`);
      logger.debug('[socket] Client joined invoice room', { socketId: socket.id, invoiceId });
    });

    socket.on('join:admin', () => {
      socket.join('admin:global');
      logger.debug('[socket] Client joined admin global room', { socketId: socket.id });
    });

    // Chat Typing Indicators
    socket.on('typing:start', (data: { chatRoomId: string; userId: string; username: string }) => {
      socket.to(`invoice:${data.chatRoomId}`).emit('typing:start', data);
      socket.to(`merchant:${data.chatRoomId}`).emit('typing:start', data);
    });

    socket.on('typing:stop', (data: { chatRoomId: string; userId: string }) => {
      socket.to(`invoice:${data.chatRoomId}`).emit('typing:stop', data);
      socket.to(`merchant:${data.chatRoomId}`).emit('typing:stop', data);
    });

    socket.on('disconnect', () => {
      logger.info('[socket] Client disconnected', { socketId: socket.id });
    });
  });

  logger.info('✅ Socket.IO server initialized with Redis Adapter');
  return io;
}

export function getSocketServer(): SocketIOServer {
  if (!io) {
    throw new Error('Socket.IO server has not been initialized');
  }
  return io;
}

// Room broadcast helper
export function broadcastToRoom(room: string, event: string, payload: any): void {
  if (!io) return;
  io.to(room).emit(event, payload);
  logger.debug('[socket] Broadcasted event to room', { room, event });
}
