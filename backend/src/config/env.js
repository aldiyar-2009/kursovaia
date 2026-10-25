import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import dotenv from 'dotenv';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
export const ROOT_DIR = path.resolve(__dirname, '..', '..');

// Tests set NODE_ENV=test before importing; they must not pick up the dev .env DB.
if (process.env.NODE_ENV !== 'test') {
  dotenv.config({ path: path.join(ROOT_DIR, '.env'), quiet: true });
}

const str = (key, fallback = '') => {
  const v = process.env[key];
  return v === undefined || v === '' ? fallback : v;
};
const int = (key, fallback) => {
  const n = Number.parseInt(process.env[key] ?? '', 10);
  return Number.isFinite(n) ? n : fallback;
};

const resolveFromRoot = (p) => (path.isAbsolute(p) ? p : path.resolve(ROOT_DIR, p));

/**
 * PostgreSQL connection for `pg` / Knex from raw environment variables.
 *
 * SSL rules (certificate verification is never disabled):
 *  - `PG_SSL=false` (explicit) -> plain connection.
 *  - `DATABASE_URL` set (e.g. Supabase session pooler) -> SSL on by default.
 *  - `PG_HOST`/`PG_*` config -> SSL only when `PG_SSL=true`.
 *  - With SSL: `PG_SSL_CA` (path, relative to backend/) -> `{ ca }`, else `{ rejectUnauthorized: true }`
 *    (system CA store).
 * @param {Record<string, string|undefined>} vars usually `process.env`
 */
export function buildPgConnection(vars = process.env) {
  const get = (key, fallback = '') => {
    const v = vars[key];
    return v === undefined || v === '' ? fallback : String(v);
  };
  const sslFlag = get('PG_SSL').toLowerCase();
  const sslOff = ['0', 'false', 'no', 'off'].includes(sslFlag);
  const sslOn = ['1', 'true', 'yes', 'on'].includes(sslFlag);
  const databaseUrl = get('DATABASE_URL');

  let ssl = false;
  if (!sslOff && (databaseUrl || sslOn)) {
    const caPath = get('PG_SSL_CA');
    if (caPath) {
      const full = resolveFromRoot(caPath);
      let ca;
      try {
        ca = fs.readFileSync(full);
      } catch (err) {
        throw new Error(`PG_SSL_CA: cannot read CA certificate at ${full} (${err.code ?? err.message})`);
      }
      ssl = { ca };
    } else {
      ssl = { rejectUnauthorized: true };
    }
  }

  if (databaseUrl) return { connectionString: databaseUrl, ssl };
  const port = Number.parseInt(get('PG_PORT'), 10);
  return {
    host: get('PG_HOST', 'localhost'),
    port: Number.isFinite(port) ? port : 5432,
    user: get('PG_USER', 'postgres'),
    password: get('PG_PASSWORD', 'postgres'),
    database: get('PG_DATABASE', 'studyplan'),
    ssl,
  };
}

export const env = {
  nodeEnv: str('NODE_ENV', 'development'),
  isTest: str('NODE_ENV') === 'test',
  port: int('PORT', 3000),
  host: str('HOST', '0.0.0.0'),
  corsOrigins: str('CORS_ORIGINS', '*')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean),

  db: {
    client: str('DB_CLIENT', 'sqlite') === 'pg' ? 'pg' : 'sqlite',
    sqliteFilename: str('SQLITE_FILENAME', '') === ':memory:'
      ? ':memory:'
      : resolveFromRoot(str('SQLITE_FILENAME', './data/studyplan.sqlite3')),
    // PostgreSQL connection is built lazily by buildPgConnection() (reads the CA file).
  },

  jwt: {
    secret: str('JWT_SECRET', 'dev-only-insecure-secret'),
    expiresIn: str('JWT_EXPIRES_IN', '30d'),
  },
  bcryptRounds: int('BCRYPT_ROUNDS', 10),

  uploadDir: resolveFromRoot(str('UPLOAD_DIR', './data/uploads')),
  uploadMaxBytes: int('UPLOAD_MAX_MB', 10) * 1024 * 1024,

  syncMaxBatch: int('SYNC_MAX_BATCH', 2000),
};
