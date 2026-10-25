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
 * Removes `sslmode` / `sslrootcert` / `sslcert` / `sslkey` / `ssl` query params from a
 * connection string: pg lets them override the `ssl` object (e.g. `sslmode=require`
 * would drop our `{ ca }` and certificate verification). Other params are kept verbatim.
 */
function stripSslParams(connectionString) {
  const q = connectionString.indexOf('?');
  if (q === -1) return connectionString;
  const kept = connectionString
    .slice(q + 1)
    .split('&')
    .filter((pair) => pair && !/^ssl[a-z]*$/i.test(pair.split('=')[0]));
  const base = connectionString.slice(0, q);
  return kept.length ? `${base}?${kept.join('&')}` : base;
}

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

  if (databaseUrl) return { connectionString: stripSslParams(databaseUrl), ssl };
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

/** Fallback JWT secret, allowed only for local SQLite development and tests. */
export const DEV_JWT_SECRET = 'dev-only-insecure-secret';

/**
 * JWT signing secret from raw environment variables. Without `JWT_SECRET` the server
 * refuses to start in production (`NODE_ENV=production`) or with PostgreSQL
 * (`DB_CLIENT=pg`): a public fallback secret would let anyone forge tokens.
 * @param {Record<string, string|undefined>} vars usually `process.env`
 */
export function resolveJwtSecret(vars = process.env) {
  const secret = String(vars.JWT_SECRET ?? '').trim();
  const strict = vars.NODE_ENV === 'production' || vars.DB_CLIENT === 'pg';
  // The old .env.example placeholder is as public as the dev fallback.
  const placeholder = secret === 'change-me-to-a-long-random-secret';
  if (secret && !(strict && placeholder)) return secret;
  if (strict) {
    throw new Error(
      'JWT_SECRET is required when NODE_ENV=production or DB_CLIENT=pg. Generate one with: '
        + 'node -e "console.log(require(\'crypto\').randomBytes(48).toString(\'hex\'))"',
    );
  }
  return DEV_JWT_SECRET;
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
    secret: resolveJwtSecret(process.env),
    expiresIn: str('JWT_EXPIRES_IN', '30d'),
  },
  bcryptRounds: int('BCRYPT_ROUNDS', 10),

  uploadDir: resolveFromRoot(str('UPLOAD_DIR', './data/uploads')),
  uploadMaxBytes: int('UPLOAD_MAX_MB', 10) * 1024 * 1024,

  syncMaxBatch: int('SYNC_MAX_BATCH', 2000),
};
