import { db } from '../config/db.js';
import { env } from '../config/env.js';
import { normalizeMessage, normalizeRow, SYNC_ORDER, SYNC_TABLES } from '../db/schema.js';
import { emitToGroup, emitToUser } from '../realtime/notifier.js';
import { badRequest } from '../utils/http-error.js';
import { isEpochMs, isUuid, pick, toBool, toNullableBool } from '../utils/validators.js';
import { storeMessage, validateIncomingMessage } from './chat.service.js';

/**
 * Pull window overlap. A concurrent transaction may commit rows stamped slightly
 * before our `server_time`; re-reading a few seconds back guarantees nothing is
 * missed. Duplicates are harmless because clients apply rows idempotently (LWW).
 */
export const PULL_OVERLAP_MS = 5_000;
const INITIAL_CHAT_HISTORY = 300;

function coerce(table, data) {
  const spec = SYNC_TABLES[table];
  for (const b of spec.booleans ?? []) if (b in data) data[b] = toBool(data[b]);
  for (const b of spec.nullableBooleans ?? []) if (b in data) data[b] = toNullableBool(data[b]);
  return data;
}

/**
 * Referential + permission checks for a single record. Must never throw inside the
 * transaction: on PostgreSQL a failed statement aborts the whole transaction, so all
 * checks are explicit queries instead of relying on FK violations.
 * @returns {Promise<string|null>} rejection reason
 */
async function checkReferences(trx, table, user, data) {
  if (table === 'lessons') {
    const subject = await trx('subjects').where({ id: data.subject_id, user_id: user.id }).first('id');
    if (!subject) return 'subject_id not found';
  }
  if (table === 'subtasks') {
    const task = await trx('tasks').where({ id: data.task_id, user_id: user.id }).first('id');
    if (!task) return 'task_id not found';
  }
  if (table === 'tasks') {
    const canPublish = data.is_group && user.role === 'headman' && user.group_id;
    data.is_group = Boolean(canPublish);
    data.group_id = canPublish ? user.group_id : null;
  }
  return null;
}

/**
 * Push phase: applies client changes with Last-Write-Wins inside one transaction.
 * @returns {Promise<{applied: Record<string,string[]>, rejected: object[], forced: Record<string,Set<string>>, createdMessages: object[], groupTasksChanged: boolean}>}
 */
async function applyChanges(user, changes, now) {
  const applied = {};
  const rejected = [];
  const forced = {};
  const createdMessages = [];
  let groupTasksChanged = false;

  await db.transaction(async (trx) => {
    for (const table of SYNC_ORDER) {
      const spec = SYNC_TABLES[table];
      const incoming = changes[table] ?? [];
      applied[table] = [];
      forced[table] = new Set();

      for (const record of incoming) {
        const reject = (reason) => rejected.push({ table, id: record?.id ?? null, reason });

        if (!record || typeof record !== 'object' || !isUuid(record.id)) { reject('invalid id'); continue; }
        if (!isEpochMs(record.updated_at)) { reject('updated_at must be epoch ms'); continue; }
        const validationError = spec.validate(record);
        if (validationError) { reject(validationError); continue; }

        const data = coerce(table, pick(record, spec.columns));
        // eslint-disable-next-line no-await-in-loop
        const existing = await trx(table).where({ id: data.id }).first();

        if (existing && existing.user_id !== user.id) { reject('forbidden'); continue; }

        // eslint-disable-next-line no-await-in-loop
        const refError = await checkReferences(trx, table, user, data);
        if (refError) { reject(refError); continue; }

        if (!existing) {
          // eslint-disable-next-line no-await-in-loop
          await trx(table).insert({ ...data, user_id: user.id, server_updated_at: now });
        } else if (Number(data.updated_at) > Number(existing.updated_at)) {
          const { id, ...patch } = data;
          // eslint-disable-next-line no-await-in-loop
          await trx(table).where({ id }).update({ ...patch, server_updated_at: now });
        } else {
          // Server copy is newer (or equal): server wins, send it back to the client.
          forced[table].add(data.id);
          reject('stale');
          continue;
        }

        applied[table].push(data.id);
        if (table === 'tasks' && (data.is_group || toBool(existing?.is_group))) groupTasksChanged = true;
      }
    }

    applied.chat_messages = [];
    for (const message of changes.chat_messages ?? []) {
      const error = validateIncomingMessage(user, message);
      if (error) { rejected.push({ table: 'chat_messages', id: message?.id ?? null, reason: error }); continue; }
      // eslint-disable-next-line no-await-in-loop
      const { message: stored, created } = await storeMessage(user, message, trx);
      applied.chat_messages.push(stored.id);
      if (created) createdMessages.push(stored);
    }
  });

  return { applied, rejected, forced, createdMessages, groupTasksChanged };
}

/** Pull phase: everything changed on the server since the client's cursor. */
async function collectChanges(user, lastSyncedAt, forced, applied) {
  const initial = lastSyncedAt <= 0;
  const since = Math.max(0, lastSyncedAt - PULL_OVERLAP_MS);
  const out = {};

  for (const table of SYNC_ORDER) {
    const q = db(table).where('server_updated_at', '>', since);
    if (table === 'tasks') {
      q.andWhere((w) => {
        w.where('user_id', user.id);
        if (user.group_id) w.orWhere((g) => g.where('is_group', true).andWhere('group_id', user.group_id));
      });
    } else {
      q.andWhere('user_id', user.id);
    }
    if (initial) q.andWhere('is_deleted', false);

    // eslint-disable-next-line no-await-in-loop
    const rows = await q;
    const echo = new Set(applied[table] ?? []);
    const byId = new Map(rows.filter((r) => !echo.has(r.id)).map((r) => [r.id, r]));

    const forcedIds = [...(forced[table] ?? [])].filter((id) => !byId.has(id));
    if (forcedIds.length) {
      // eslint-disable-next-line no-await-in-loop
      const extra = await db(table).whereIn('id', forcedIds);
      for (const r of extra) byId.set(r.id, r);
    }
    out[table] = [...byId.values()].map((r) => normalizeRow(table, r));
  }

  if (!user.group_id) {
    out.chat_messages = [];
  } else if (initial) {
    const rows = await db('chat_messages')
      .where({ group_id: user.group_id })
      .orderBy('created_at', 'desc')
      .limit(INITIAL_CHAT_HISTORY);
    out.chat_messages = rows.reverse().map(normalizeMessage);
  } else {
    const rows = await db('chat_messages')
      .where({ group_id: user.group_id })
      .andWhere('server_updated_at', '>', since)
      .orderBy('created_at', 'asc');
    out.chat_messages = rows.map(normalizeMessage);
  }
  return out;
}

/**
 * Batch synchronisation entry point.
 * Request : { last_synced_at, changes: { subjects, lessons, tasks, subtasks, chat_messages } }
 * Response: { server_time, applied, rejected, changes, group }
 */
export async function synchronize(user, body) {
  const lastSyncedAt = Number(body?.last_synced_at ?? 0);
  if (!Number.isFinite(lastSyncedAt) || lastSyncedAt < 0) throw badRequest('last_synced_at must be epoch ms');

  const changes = body?.changes ?? {};
  if (typeof changes !== 'object' || Array.isArray(changes)) throw badRequest('changes must be an object');
  for (const table of [...SYNC_ORDER, 'chat_messages']) {
    const list = changes[table];
    if (list === undefined) continue;
    if (!Array.isArray(list)) throw badRequest(`changes.${table} must be an array`);
    if (list.length > env.syncMaxBatch) throw badRequest(`changes.${table} exceeds SYNC_MAX_BATCH (${env.syncMaxBatch})`);
  }

  const now = Date.now();
  const result = await applyChanges(user, changes, now);

  // Side effects only after a successful commit.
  for (const message of result.createdMessages) emitToGroup(user.group_id, 'chat:message', message);
  const touched = SYNC_ORDER.filter((t) => result.applied[t]?.length);
  if (touched.length) emitToUser(user.id, 'sync:changed', { tables: touched });
  if (result.groupTasksChanged) emitToGroup(user.group_id, 'sync:changed', { tables: ['tasks'] });

  const pulled = await collectChanges(user, lastSyncedAt, result.forced, result.applied);
  const group = user.group_id ? await db('groups').where({ id: user.group_id }).first() : null;

  return {
    server_time: now,
    applied: result.applied,
    rejected: result.rejected,
    changes: pulled,
    group: group ?? null,
  };
}
