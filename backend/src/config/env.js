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
const bool = (key, fallback = false) => {
  const v = process.env[key];
  if (v === undefined || v === '') return fallback;
  return ['1', 'true', 'yes', 'on'].includes(v.toLowerCase());
};

const resolveFromRoot = (p) => (path.isAbsolute(p) ? p : path.resolve(ROOT_DIR, p));

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
    databaseUrl: str('DATABASE_URL', ''),
    pg: {
      host: str('PG_HOST', 'localhost'),
      port: int('PG_PORT', 5432),
      user: str('PG_USER', 'postgres'),
      password: str('PG_PASSWORD', 'postgres'),
      database: str('PG_DATABASE', 'studyplan'),
      ssl: bool('PG_SSL', false),
    },
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
