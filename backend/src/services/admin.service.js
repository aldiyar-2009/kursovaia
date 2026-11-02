import bcrypt from 'bcryptjs';
import { db } from '../config/db.js';
import { env } from '../config/env.js';
import { normalizeUser } from '../db/schema.js';
import { badRequest, conflict, forbidden, notFound } from '../utils/http-error.js';
import { isNonEmptyString, newId, toBool } from '../utils/validators.js';
import { EMAIL_RE } from './auth.service.js';

export const ROLES = ['user', 'admin'];

const USER_COLUMNS = [
  'users.id', 'users.email', 'users.name', 'users.role', 'users.is_blocked', 'users.is_demo',
  'users.edition', 'users.sn_group', 'users.group_id', 'users.created_at', 'users.updated_at', 'groups.title as group_title',
];

function usersQuery() {
  return db('users').leftJoin('groups', 'groups.id', 'users.group_id').select(USER_COLUMNS);
}

async function findUser(id) {
  const user = await usersQuery().where('users.id', id).first();
  if (!user) throw notFound('User not found');
  return normalizeUser(user);
}

/** Users ordered by creation date (newest first); `q` filters by name or email. */
export async function listUsers({ q, role, blocked } = {}) {
  const query = usersQuery().orderBy('users.created_at', 'desc');
  if (typeof q === 'string' && q.trim()) {
    const like = `%${q.trim().toLowerCase()}%`;
    query.where((w) => w.whereRaw('LOWER(users.name) LIKE ?', [like]).orWhereRaw('LOWER(users.email) LIKE ?', [like]));
  }
  if (ROLES.includes(role)) query.where('users.role', role);
  if (blocked === 'true' || blocked === 'false') query.where('users.is_blocked', blocked === 'true');
  return (await query).map(normalizeUser);
}

function validateRole(role) {
  if (role !== undefined && !ROLES.includes(role)) throw badRequest(`role must be one of ${ROLES.join(', ')}`);
}

async function normalizedEmail(email, exceptId = null) {
  if (typeof email !== 'string' || !EMAIL_RE.test(email.trim())) throw badRequest('Valid email is required');
  const value = email.trim().toLowerCase();
  const taken = await db('users').where({ email: value }).whereNot({ id: exceptId ?? '' }).first('id');
  if (taken) throw conflict('Email is already registered');
  return value;
}

function validatePassword(password) {
  if (typeof password !== 'string' || password.length < 6) throw badRequest('Password must be at least 6 characters');
}

export async function createUser({ email, password, name, role = 'user' }) {
  if (!isNonEmptyString(name, 120)) throw badRequest('Name is required');
  validateRole(role);
  validatePassword(password);
  const now = Date.now();
  const id = newId();
  await db('users').insert({
    id,
    email: await normalizedEmail(email),
    password_hash: await bcrypt.hash(password, env.bcryptRounds),
    name: name.trim(),
    role,
    is_blocked: false,
    is_demo: false,
    group_id: null,
    created_at: now,
    updated_at: now,
  });
  return findUser(id);
}

/** Edits name / email / role / password. An admin cannot take the admin role away from themselves. */
export async function updateUser(admin, id, { email, password, name, role }) {
  const user = await findUser(id);
  const patch = {};
  if (name !== undefined) {
    if (!isNonEmptyString(name, 120)) throw badRequest('Valid name is required');
    patch.name = name.trim();
  }
  if (email !== undefined) patch.email = await normalizedEmail(email, id);
  if (role !== undefined) {
    validateRole(role);
    if (admin.id === id && role !== 'admin') throw forbidden('You cannot remove your own admin role');
    patch.role = role;
  }
  if (password !== undefined) {
    validatePassword(password);
    patch.password_hash = await bcrypt.hash(password, env.bcryptRounds);
  }
  if (Object.keys(patch).length === 0) return user;
  patch.updated_at = Date.now();
  await db('users').where({ id }).update(patch);
  return findUser(id);
}

export async function setBlocked(admin, id, blocked) {
  await findUser(id);
  if (admin.id === id && blocked) throw forbidden('You cannot block yourself');
  await db('users').where({ id }).update({ is_blocked: blocked, updated_at: Date.now() });
  return findUser(id);
}

export async function stats() {
  const count = async (q) => Number((await q.count({ n: '*' }).first()).n);
  return {
    users: await count(db('users')),
    admins: await count(db('users').where({ role: 'admin' })),
    blocked: await count(db('users').where({ is_blocked: true })),
    demo: await count(db('users').where({ is_demo: true })),
    groups: await count(db('groups')),
    tasks: await count(db('tasks').where({ is_deleted: false })),
    announcements: await count(db('announcements')),
    published: await count(db('announcements').where({ is_published: true })),
  };
}

// ---------------------------------------------------------------- announcements

function normalizeAnnouncement(row) {
  return row ? { ...row, is_published: toBool(row.is_published) } : row;
}

async function findAnnouncement(id) {
  const row = await db('announcements')
    .leftJoin('users', 'users.id', 'announcements.author_id')
    .select('announcements.*', 'users.name as author_name')
    .where('announcements.id', id)
    .first();
  if (!row) throw notFound('Announcement not found');
  return normalizeAnnouncement(row);
}

function validateAnnouncement({ title, body }, partial) {
  if (!(partial && title === undefined) && !isNonEmptyString(title, 200)) throw badRequest('title is required (<=200 chars)');
  if (!(partial && body === undefined) && !isNonEmptyString(body, 20_000)) throw badRequest('body is required (<=20000 chars)');
}

export async function listAnnouncements() {
  const rows = await db('announcements')
    .leftJoin('users', 'users.id', 'announcements.author_id')
    .select('announcements.*', 'users.name as author_name')
    .orderBy('announcements.created_at', 'desc');
  return rows.map(normalizeAnnouncement);
}

export async function createAnnouncement(admin, { title, body, is_published: isPublished }) {
  validateAnnouncement({ title, body }, false);
  const now = Date.now();
  const publish = toBool(isPublished);
  const id = newId();
  await db('announcements').insert({
    id,
    title: title.trim(),
    body: body.trim(),
    is_published: publish,
    published_at: publish ? now : null,
    author_id: admin.id,
    created_at: now,
    updated_at: now,
  });
  return findAnnouncement(id);
}

export async function updateAnnouncement(id, { title, body }) {
  await findAnnouncement(id);
  validateAnnouncement({ title, body }, true);
  const patch = { updated_at: Date.now() };
  if (title !== undefined) patch.title = title.trim();
  if (body !== undefined) patch.body = body.trim();
  await db('announcements').where({ id }).update(patch);
  return findAnnouncement(id);
}

export async function setPublished(id, publish) {
  const current = await findAnnouncement(id);
  const now = Date.now();
  await db('announcements').where({ id }).update({
    is_published: publish,
    // Keep the first publication date when re-publishing an edited announcement.
    published_at: publish ? (current.published_at ?? now) : null,
    updated_at: now,
  });
  return findAnnouncement(id);
}

export async function deleteAnnouncement(id) {
  await findAnnouncement(id);
  await db('announcements').where({ id }).del();
  return { success: true };
}

/** What the mobile app shows: published announcements, newest first. */
export async function publishedAnnouncements() {
  const rows = await db('announcements')
    .where({ is_published: true })
    .select('id', 'title', 'body', 'published_at', 'updated_at')
    .orderBy('published_at', 'desc')
    .limit(50);
  return rows;
}
