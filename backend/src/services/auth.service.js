import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { db } from '../config/db.js';
import { env } from '../config/env.js';
import { normalizeUser } from '../db/schema.js';
import { badRequest, conflict, unauthorized } from '../utils/http-error.js';
import { isNonEmptyString, newId } from '../utils/validators.js';

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function signToken(user) {
  return jwt.sign({ sub: user.id, role: user.role }, env.jwt.secret, { expiresIn: env.jwt.expiresIn });
}

export function verifyToken(token) {
  try {
    return jwt.verify(token, env.jwt.secret);
  } catch {
    throw unauthorized('Invalid or expired token');
  }
}

export async function getUserById(id) {
  return db('users').where({ id }).first();
}

export async function getGroupById(id) {
  if (!id) return null;
  return db('groups').where({ id }).first();
}

/** Response payload shared by register/login/me. */
export async function buildSession(user) {
  const group = await getGroupById(user.group_id);
  return { token: signToken(user), user: normalizeUser(user), group: group ?? null };
}

export async function register({ email, password, name, invite_code: inviteCode }) {
  if (!isNonEmptyString(name, 120)) throw badRequest('Name is required');
  if (typeof email !== 'string' || !EMAIL_RE.test(email.trim())) throw badRequest('Valid email is required');
  if (typeof password !== 'string' || password.length < 6) throw badRequest('Password must be at least 6 characters');

  const normalizedEmail = email.trim().toLowerCase();
  const existing = await db('users').where({ email: normalizedEmail }).first();
  if (existing) throw conflict('Email is already registered');

  let groupId = null;
  if (inviteCode) {
    const group = await db('groups').where({ invite_code: String(inviteCode).trim().toUpperCase() }).first();
    if (!group) throw badRequest('Invite code not found');
    groupId = group.id;
  }

  const now = Date.now();
  const user = {
    id: newId(),
    email: normalizedEmail,
    password_hash: await bcrypt.hash(password, env.bcryptRounds),
    name: name.trim(),
    role: 'student',
    group_id: groupId,
    created_at: now,
    updated_at: now,
  };
  await db('users').insert(user);
  return buildSession(user);
}

export async function login({ email, password }) {
  if (typeof email !== 'string' || typeof password !== 'string') throw badRequest('Email and password are required');
  const user = await db('users').where({ email: email.trim().toLowerCase() }).first();
  if (!user || !user.password_hash || !(await bcrypt.compare(password, user.password_hash))) {
    throw unauthorized('Wrong email or password');
  }
  return buildSession(user);
}

export async function updateMe(user, { name }) {
  if (name !== undefined) {
    if (!isNonEmptyString(name, 120)) throw badRequest('Valid name is required');
    await db('users').where({ id: user.id }).update({ name: name.trim(), updated_at: Date.now() });
    user.name = name.trim();
  }
  return buildSession(user);
}


