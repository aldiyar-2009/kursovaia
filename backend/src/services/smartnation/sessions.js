import { db } from '../../config/db.js';
import { badRequest } from '../../utils/http-error.js';
import { decrypt } from '../../utils/secret-box.js';
import { parseJson } from '../../utils/validators.js';
import { SmartNationClient } from './client.js';
import { buildSnapshot } from './sync.js';

/**
 * Logged-in SmartNation clients kept in memory (no fresh login on every request)
 * and the snapshot cache in `sn_snapshots` (JSON text).
 */

const TTL_MS = 20 * 60 * 1000;
const sessions = new Map(); // userId -> { client, expires }
const inFlight = new Map(); // userId -> Promise<snapshot> (never build two snapshots at once)

let clientFactory = (opts) => new SmartNationClient(opts);

/** Replaces the client factory (tests point it at a fake portal). Clears cached sessions. */
export function setClientFactory(fn) {
  clientFactory = fn ?? ((opts) => new SmartNationClient(opts));
  sessions.clear();
}

export const createClient = (opts = {}) => clientFactory(opts);

export function remember(userId, client) {
  sessions.set(userId, { client, expires: Date.now() + TTL_MS });
}

async function clientFor(user) {
  const cached = sessions.get(user.id);
  if (cached && cached.expires > Date.now()) return cached.client;
  if (!user.sn_credentials_enc) throw badRequest('SmartNation is not connected');

  const { login, password } = decrypt(user.sn_credentials_enc);
  const client = createClient();
  await client.login(login, password);
  remember(user.id, client);
  return client;
}

/** Stores a snapshot for the user (insert or replace). */
export async function saveSnapshot(userId, data, conn = db) {
  const now = Date.now();
  await conn('sn_snapshots')
    .insert({ user_id: userId, data: JSON.stringify(data), synced_at: now })
    .onConflict('user_id')
    .merge();
  return now;
}

/** Builds a fresh snapshot from SmartNation and stores it. */
export function refreshSnapshot(user) {
  if (inFlight.has(user.id)) return inFlight.get(user.id);
  const job = (async () => {
    const client = await clientFor(user);
    const data = await buildSnapshot(client);
    await saveSnapshot(user.id, data);
    return data;
  })().finally(() => inFlight.delete(user.id));
  inFlight.set(user.id, job);
  return job;
}

/** Waits for a snapshot build already running for the user, if any. */
export const pendingSnapshot = (userId) => inFlight.get(userId) ?? null;

/** `{ data, synced_at }` of the stored snapshot, or null. */
export async function getStoredSnapshot(userId) {
  const row = await db('sn_snapshots').where({ user_id: userId }).first();
  if (!row) return null;
  return { data: parseJson(row.data), synced_at: Number(row.synced_at) };
}
