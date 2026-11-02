import { db } from '../config/db.js';
import { env } from '../config/env.js';
import { badRequest, HttpError } from '../utils/http-error.js';
import { encrypt } from '../utils/secret-box.js';
import { generateInviteCode, newId, toBool } from '../utils/validators.js';
import { buildSession, userBlocked } from './auth.service.js';
import * as snSessions from './smartnation/sessions.js';
import { fetchIdentity } from './smartnation/sync.js';
import { normGroup } from './timetable.service.js';

/**
 * College edition: sign-in through SmartNation (college.smartnation.kz) and the
 * cached grades/assignments snapshot. The password is checked by SmartNation
 * itself; we keep it only encrypted, to rebuild the snapshot later.
 */

export const MIN_REFRESH_MS = 60 * 1000;
export const COLLEGE_SEMESTER_START = '2026-09-01';

export const notCollege = () => new HttpError(403, 'NOT_COLLEGE', 'Available only for college accounts');

async function uniqueInviteCode(trx) {
  for (let i = 0; i < 10; i += 1) {
    const code = generateInviteCode();
    // eslint-disable-next-line no-await-in-loop
    if (!(await trx('groups').where({ invite_code: code }).first('id'))) return code;
  }
  throw new Error('Could not generate a unique invite code');
}

/** The app group of a college group (e.g. ПО2501); created on first use. */
export async function findOrCreateCollegeGroup(trx, snGroup, createdBy) {
  const existing = await trx('groups').where({ sn_group_name: snGroup }).first();
  if (existing) return existing;
  const now = Date.now();
  const group = {
    id: newId(),
    title: snGroup,
    invite_code: await uniqueInviteCode(trx),
    semester: 1,
    semester_start: COLLEGE_SEMESTER_START,
    sn_group_name: snGroup,
    created_by: createdBy,
    created_at: now,
    updated_at: now,
  };
  await trx('groups').insert(group);
  return group;
}

const logError = (msg, err) => {
  if (!env.isTest) console.error(msg, err?.message ?? err);
};

/**
 * POST /auth/smartnation: checks the credentials in SmartNation, finds or creates the
 * college user by IIN/login and puts them into the app group of their college group.
 */
export async function loginSmartNation({ login, password } = {}) {
  const id = typeof login === 'string' ? login.trim() : '';
  if (!id || id.length > 32 || typeof password !== 'string' || !password) {
    throw badRequest('SmartNation login (IIN) and password are required');
  }

  const client = snSessions.createClient();
  await client.login(id, password); // 401 SN_INVALID_CREDENTIALS / 502 SN_UNAVAILABLE
  const identity = await fetchIdentity(client);
  const snGroup = identity.group ? normGroup(identity.group).slice(0, 32) || null : null;

  const user = await db.transaction(async (trx) => {
    const now = Date.now();
    let row = await trx('users').where({ sn_iin: id }).first();
    if (row && toBool(row.is_blocked)) throw userBlocked();

    const fields = {
      edition: 'college',
      sn_credentials_enc: encrypt({ login: id, password }),
      sn_group: snGroup,
      updated_at: now,
    };
    if (row) {
      await trx('users').where({ id: row.id }).update(fields);
    } else {
      row = {
        id: newId(),
        email: null,
        password_hash: null,
        name: (identity.fullName || id).slice(0, 120),
        role: 'user',
        is_blocked: false,
        is_demo: false,
        sn_iin: id,
        group_id: null,
        created_at: now,
        ...fields,
      };
      await trx('users').insert(row);
    }

    // Join the college group automatically when not a member of any group yet.
    if (!row.group_id && snGroup) {
      const group = await findOrCreateCollegeGroup(trx, snGroup, row.id);
      await trx('users').where({ id: row.id }).update({ group_id: group.id });
    }
    return trx('users').where({ id: row.id }).first();
  });

  snSessions.remember(user.id, client);
  // Grades and assignments are collected in the background; the app fetches /college/snapshot.
  snSessions.refreshSnapshot(user).catch((err) => logError('[smartnation] snapshot:', err));

  return buildSession(user);
}

function assertCollege(user) {
  if (user.edition !== 'college') throw notCollege();
}

/** GET /college/snapshot: the cached snapshot, built on the first request. */
export async function getSnapshot(user) {
  assertCollege(user);
  const pending = snSessions.pendingSnapshot(user.id);
  if (pending) return { snapshot: await pending };
  const stored = await snSessions.getStoredSnapshot(user.id);
  if (stored?.data) return { snapshot: stored.data };
  if (toBool(user.is_demo)) return { snapshot: null };
  return { snapshot: await snSessions.refreshSnapshot(user) };
}

/** POST /college/refresh: rebuilds the snapshot, at most once a minute. Demo users get the stored one. */
export async function refreshSnapshot(user) {
  assertCollege(user);
  const stored = await snSessions.getStoredSnapshot(user.id);
  if (toBool(user.is_demo)) return { snapshot: stored?.data ?? null };
  if (stored?.data && Date.now() - stored.synced_at < MIN_REFRESH_MS) return { snapshot: stored.data };
  return { snapshot: await snSessions.refreshSnapshot(user) };
}
