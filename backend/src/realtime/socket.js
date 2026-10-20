import { Server } from 'socket.io';
import { env } from '../config/env.js';
import { getUserById, verifyToken } from '../services/auth.service.js';
import { sendMessage } from '../services/chat.service.js';
import { groupRoom, setIo, userRoom } from './notifier.js';

/**
 * Socket.IO protocol
 *  handshake : io(url, { auth: { token: '<JWT>' } })
 *  client -> server
 *    'chat:send'   (message, ack)  message = { id, message_type, content, payload_json, created_at }
 *                                  ack({ ok: true, message }) | ack({ ok: false, error })
 *    'chat:typing' ()
 *  server -> client
 *    'chat:message'  stored message (also echoed to the sender; clients dedupe by id)
 *    'chat:updated'  message changed (e.g. pinned)
 *    'chat:typing'   { user_id, name }
 *    'presence'      { online: number }
 *    'sync:changed'  { tables: string[] }  -> client should run POST /api/sync
 */
export function attachSocketServer(httpServer) {
  const io = new Server(httpServer, {
    cors: { origin: env.corsOrigins.includes('*') ? true : env.corsOrigins, credentials: true },
    pingInterval: 20_000,
    pingTimeout: 20_000,
  });

  io.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth?.token ?? socket.handshake.query?.token;
      if (!token) return next(new Error('UNAUTHORIZED'));
      const payload = verifyToken(String(token));
      const user = await getUserById(payload.sub);
      if (!user) return next(new Error('UNAUTHORIZED'));
      socket.data.userId = user.id;
      socket.data.user = user;
      return next();
    } catch {
      return next(new Error('UNAUTHORIZED'));
    }
  });

  const broadcastPresence = async (groupId) => {
    if (!groupId) return;
    const sockets = await io.in(groupRoom(groupId)).fetchSockets();
    const online = new Set(sockets.map((s) => s.data.userId)).size;
    io.to(groupRoom(groupId)).emit('presence', { online });
  };

  // NOTE: must stay synchronous so listeners exist before the first client event arrives.
  io.on('connection', (socket) => {
    const { user } = socket.data;
    socket.data.groupId = user.group_id;
    socket.join(userRoom(user.id));
    if (user.group_id) {
      socket.join(groupRoom(user.group_id));
      broadcastPresence(user.group_id).catch(() => {});
    }

    socket.on('chat:send', async (message, ack) => {
      const reply = typeof ack === 'function' ? ack : () => {};
      try {
        // Re-read the user: role/group could have changed since the socket connected.
        const fresh = await getUserById(socket.data.userId);
        const stored = await sendMessage(fresh, message);
        reply({ ok: true, message: stored });
      } catch (err) {
        reply({ ok: false, error: err?.message ?? 'Failed to send message' });
      }
    });

    socket.on('chat:typing', async () => {
      if (!socket.data.groupId) return;
      socket.to(groupRoom(socket.data.groupId)).emit('chat:typing', { user_id: user.id, name: user.name });
    });

    socket.on('disconnect', () => {
      broadcastPresence(socket.data.groupId).catch(() => {});
    });
  });

  setIo(io);
  return io;
}
