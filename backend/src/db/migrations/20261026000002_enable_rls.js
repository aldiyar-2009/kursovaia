/**
 * Supabase exposes every table in the `public` schema through its REST API (anon key).
 * Enabling Row Level Security without policies makes those tables unreachable via REST,
 * while the backend (connecting as the table owner `postgres`) is unaffected.
 * Covers all tables present at this point, including `knex_migrations*`. Tables created
 * by later migrations must enable RLS themselves.
 * PostgreSQL only; no-op on SQLite.
 * @param {import('knex').Knex} knex
 */
async function publicTables(knex) {
  const { rows } = await knex.raw("SELECT tablename FROM pg_tables WHERE schemaname = 'public'");
  return rows.map((r) => r.tablename);
}

const isPg = (knex) => knex.client.config.client === 'pg';

/** @param {import('knex').Knex} knex */
export async function up(knex) {
  if (!isPg(knex)) return;
  for (const table of await publicTables(knex)) {
    // eslint-disable-next-line no-await-in-loop
    await knex.raw('ALTER TABLE ?? ENABLE ROW LEVEL SECURITY', [`public.${table}`]);
  }
}

/** @param {import('knex').Knex} knex */
export async function down(knex) {
  if (!isPg(knex)) return;
  for (const table of await publicTables(knex)) {
    // eslint-disable-next-line no-await-in-loop
    await knex.raw('ALTER TABLE ?? DISABLE ROW LEVEL SECURITY', [`public.${table}`]);
  }
}
