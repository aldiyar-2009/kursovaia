import knexFactory from 'knex';
import pg from 'pg';
import { buildKnexConfig } from '../../knexfile.js';

// PostgreSQL returns BIGINT (int8, OID 20) as string by default. All our bigints are
// epoch-milliseconds which safely fit into JS numbers.
pg.types.setTypeParser(20, (v) => (v === null ? null : Number.parseInt(v, 10)));

export const db = knexFactory(buildKnexConfig());

export const isPg = () => db.client.config.client === 'pg';

export async function closeDb() {
  await db.destroy();
}
