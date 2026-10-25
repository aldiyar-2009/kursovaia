import fs from 'node:fs';
import path from 'node:path';
import { buildPgConnection, env, ROOT_DIR } from './src/config/env.js';

const migrations = {
  directory: path.join(ROOT_DIR, 'src', 'db', 'migrations'),
  loadExtensions: ['.js'],
  tableName: 'knex_migrations',
};
const seeds = {
  directory: path.join(ROOT_DIR, 'src', 'db', 'seeds'),
  loadExtensions: ['.js'],
};

/** Builds a Knex config for the currently selected DB_CLIENT. */
export function buildKnexConfig() {
  if (env.db.client === 'pg') {
    return {
      client: 'pg',
      connection: buildPgConnection(process.env),
      pool: { min: 1, max: 10 },
      migrations,
      seeds,
    };
  }

  if (env.db.sqliteFilename !== ':memory:') {
    fs.mkdirSync(path.dirname(env.db.sqliteFilename), { recursive: true });
  }
  return {
    client: 'sqlite3',
    connection: { filename: env.db.sqliteFilename },
    useNullAsDefault: true,
    // One connection: required for :memory: and avoids SQLITE_BUSY in dev.
    pool: {
      min: 1,
      max: 1,
      afterCreate: (conn, done) => conn.run('PRAGMA foreign_keys = ON', done),
    },
    migrations,
    seeds,
  };
}

const config = buildKnexConfig();

export default {
  development: config,
  test: config,
  production: config,
};
