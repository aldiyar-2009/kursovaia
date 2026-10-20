import { db } from '../config/db.js';
import { normalizeUser } from '../db/schema.js';
import { badRequest, conflict, forbidden, notFound } from '../utils/http-error.js';
import { generateInviteCode, isDateStr, isNonEmptyString, newId } from '../utils/validators.js';
import { buildSession, getUserById } from './auth.service.js';

async function uniqueInviteCode(trx) {
  for (let i = 0; i < 10; i += 1) {
    const code = generateInviteCode();
    // eslint-disable-next-line no-await-in-loop
    const taken = await trx('groups').where({ invite_code: code }).first();
    if (!taken) return code;
  }
  throw new Error('Could not generate a unique invite code');
}

/** Creates a group; the creator becomes its headman. */
export async function createGroup(userId, { title, semester, semester_start: semesterStart }) {
  if (!isNonEmptyString(title, 64)) throw badRequest('Group title is required (<=64 chars)');
  if (semesterStart != null && !isDateStr(semesterStart)) throw badRequest('semester_start must be YYYY-MM-DD');
  const sem = Number.isInteger(semester) && semester > 0 && semester <= 12 ? semester : 1;

  const user = await db.transaction(async (trx) => {
    const now = Date.now();
    const group = {
      id: newId(),
      title: title.trim(),
      invite_code: await uniqueInviteCode(trx),
      semester: sem,
      semester_start: semesterStart ?? null,
      created_by: userId,
      created_at: now,
      updated_at: now,
    };
    await trx('groups').insert(group);
    await trx('users').where({ id: userId }).update({ group_id: group.id, role: 'headman', updated_at: now });
    return trx('users').where({ id: userId }).first();
  });
  return buildSession(user);
}

export async function joinGroup(userId, inviteCode) {
  if (!isNonEmptyString(inviteCode, 16)) throw badRequest('invite_code is required');
  const group = await db('groups').where({ invite_code: inviteCode.trim().toUpperCase() }).first();
  if (!group) throw notFound('Invite code not found');
  const user = await getUserById(userId);
  if (user.group_id === group.id) throw conflict('You are already a member of this group');
  await db('users').where({ id: userId }).update({ group_id: group.id, role: 'student', updated_at: Date.now() });
  return buildSession(await getUserById(userId));
}

export async function leaveGroup(userId) {
  await db('users').where({ id: userId }).update({ group_id: null, role: 'student', updated_at: Date.now() });
  return buildSession(await getUserById(userId));
}

export async function getMyGroup(user) {
  if (!user.group_id) return { group: null, members: [] };
  const group = await db('groups').where({ id: user.group_id }).first();
  const members = await db('users')
    .where({ group_id: user.group_id })
    .orderBy([{ column: 'role', order: 'asc' }, { column: 'name', order: 'asc' }]);
  return { group, members: members.map(normalizeUser) };
}

export async function updateGroup(user, { title, semester, semester_start: semesterStart }) {
  if (!user.group_id) throw badRequest('You are not in a group');
  if (user.role !== 'headman') throw forbidden('Only the headman can edit the group');
  const patch = { updated_at: Date.now() };
  if (title !== undefined) {
    if (!isNonEmptyString(title, 64)) throw badRequest('Invalid title');
    patch.title = title.trim();
  }
  if (semester !== undefined) {
    if (!(Number.isInteger(semester) && semester > 0 && semester <= 12)) throw badRequest('Invalid semester');
    patch.semester = semester;
  }
  if (semesterStart !== undefined) {
    if (semesterStart !== null && !isDateStr(semesterStart)) throw badRequest('semester_start must be YYYY-MM-DD');
    patch.semester_start = semesterStart;
  }
  await db('groups').where({ id: user.group_id }).update(patch);
  return getMyGroup(user);
}
