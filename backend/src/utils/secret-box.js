import crypto from 'node:crypto';
import { env } from '../config/env.js';

/** SmartNation credentials encryption (AES-256-GCM). Key: SN_ENC_KEY, else the JWT secret. */
const key = () => crypto.createHash('sha256').update(env.smartnation.encKey).digest();

/** Encrypts a JSON-serialisable value into `iv.tag.data` (base64 parts). */
export function encrypt(obj) {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', key(), iv);
  const data = Buffer.concat([cipher.update(JSON.stringify(obj), 'utf8'), cipher.final()]);
  return [iv, cipher.getAuthTag(), data].map((b) => b.toString('base64')).join('.');
}

export function decrypt(str) {
  const [iv, tag, data] = String(str).split('.').map((s) => Buffer.from(s, 'base64'));
  const decipher = crypto.createDecipheriv('aes-256-gcm', key(), iv);
  decipher.setAuthTag(tag);
  return JSON.parse(Buffer.concat([decipher.update(data), decipher.final()]).toString('utf8'));
}
