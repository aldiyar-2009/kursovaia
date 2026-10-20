import crypto from 'node:crypto';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const TIME_RE = /^([01]\d|2[0-3]):[0-5]\d$/;

export const newId = () => crypto.randomUUID();
export const isUuid = (v) => typeof v === 'string' && UUID_RE.test(v);
export const isDateStr = (v) => typeof v === 'string' && DATE_RE.test(v);
export const isTimeStr = (v) => typeof v === 'string' && TIME_RE.test(v);
export const isNonEmptyString = (v, max = 10_000) => typeof v === 'string' && v.trim().length > 0 && v.length <= max;
export const isEpochMs = (v) => Number.isInteger(v) && v >= 0 && v < 32503680000000; // < year 3000

/** SQLite returns 0/1 for booleans, PostgreSQL returns true/false. */
export const toBool = (v) => v === true || v === 1 || v === '1' || v === 'true';

export const toNullableBool = (v) => (v === null || v === undefined ? null : toBool(v));

/** Parses JSON stored as TEXT (SQLite) or already-parsed JSONB (PostgreSQL). */
export function parseJson(v) {
  if (v === null || v === undefined || v === '') return null;
  if (typeof v === 'object') return v;
  try {
    return JSON.parse(v);
  } catch {
    return null;
  }
}

/** Human friendly 6-char invite code without ambiguous characters. */
export function generateInviteCode(length = 6) {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const bytes = crypto.randomBytes(length);
  let out = '';
  for (let i = 0; i < length; i += 1) out += alphabet[bytes[i] % alphabet.length];
  return out;
}

export function pick(obj, keys) {
  const out = {};
  for (const k of keys) if (Object.prototype.hasOwnProperty.call(obj, k)) out[k] = obj[k];
  return out;
}
