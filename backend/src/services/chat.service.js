import { db } from '../config/db.js';
import { HEADMAN_ONLY_MESSAGE_TYPES, MESSAGE_TYPES, normalizeMessage } from '../db/schema.js';
import { emitToGroup } from '../realtime/notifier.js';
import { badRequest, forbidden, notFound } from '../utils/http-error.js';
import { isEpochMs, isNonEmptyString, isUuid } from '../utils/validators.js';

/**
 * Validates a message coming from a client. Returns an error string or null.
 * @param {object} user DB user row
 * @param {object} m incoming message
 */
export function validateIncomingMessage(user, m) {
  if (!user.group_id) return 'You are not in a group';
  if (!m || typeof m !== 'object') return 'Message must be an object';
  if (!isUuid(m.id)) return 'id must be a client generated UUID';
  const type = m.message_type ?? 'text';
  if (!MESSAGE_TYPES.includes(type)) return `message_type must be one of ${MESSAGE_TYPES.join(', ')}`;
  if (HEADMAN_ONLY_MESSAGE_TYPES.includes(type) && user.role !== 'headman') return 'Only the headman can post this message type';
  if (!isNonEmptyString(m.content, 8000)) return 'content is required (<=8000 chars)';
  if (m.created_at != null && !isEpochMs(m.created_at)) return 'created_at must be epoch ms';
  if (m.payload_json != null && typeof m.payload_json !== 'object' && typeof m.payload_json !== 'string') {
    return 'payload_json must be an object';
  }
  return null;
}

function serializePayload(payload) {
  if (payload == null) return null;
  if (typeof payload === 'string') {
    try {
      return JSON.stringify(JSON.parse(payload));
    } catch {
      return null;
    }
  }
  return JSON.stringify(payload);
}

/**
 * Idempotently stores a chat message (the client UUID is the primary key, so an offline
 * message re-sent after reconnect is never duplicated).
 * @returns {{ message: object, created: boolean }}
 */
export async function storeMessage(user, m, trx = db) {
  const existing = await trx('chat_messages').where({ id: m.id }).first();
  if (existing) return { message: normalizeMessage(existing), created: false };

  const now = Date.now();
  const row = {
    id: m.id,
    group_id: user.group_id,
    sender_id: user.id,
    sender_name: user.name,
    message_type: m.message_type ?? 'text',
    content: m.content.trim(),
    payload_json: serializePayload(m.payload_json),
    is_pinned: false,
    // Clamp client clock: never in the future relative to the server.
    created_at: Math.min(m.created_at ?? now, now),
    server_updated_at: now,
  };
  await trx('chat_messages').insert(row);
  return { message: normalizeMessage(row), created: true };
}

/** Validates, stores and broadcasts a message. Used by both REST and Socket.IO. */
export async function sendMessage(user, m) {
  const error = validateIncomingMessage(user, m);
  if (error) throw badRequest(error);
  const result = await storeMessage(user, m);
  if (result.created) emitToGroup(user.group_id, 'chat:message', result.message);
  return result.message;
}

export async function listMessages(user, { before, limit } = {}) {
  if (!user.group_id) return [];
  const take = Math.min(Math.max(Number.parseInt(limit, 10) || 50, 1), 200);
  const q = db('chat_messages').where({ group_id: user.group_id });
  const beforeNum = Number.parseInt(before, 10);
  if (Number.isFinite(beforeNum)) q.andWhere('created_at', '<', beforeNum);
  const rows = await q.orderBy('created_at', 'desc').limit(take);
  return rows.reverse().map(normalizeMessage);
}

export async function setPinned(user, messageId, pinned) {
  if (user.role !== 'headman') throw forbidden('Only the headman can pin messages');
  const msg = await db('chat_messages').where({ id: messageId, group_id: user.group_id }).first();
  if (!msg) throw notFound('Message not found');
  await db('chat_messages')
    .where({ id: messageId })
    .update({ is_pinned: Boolean(pinned), server_updated_at: Date.now() });
  const updated = normalizeMessage(await db('chat_messages').where({ id: messageId }).first());
  emitToGroup(user.group_id, 'chat:updated', updated);
  return updated;
}
