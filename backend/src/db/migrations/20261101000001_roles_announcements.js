/**
 * Administration: user roles (`user` | `admin`), blocking, demo accounts and
 * announcements managed from the admin panel and shown in the mobile app.
 * Legacy roles `student` / `headman` become `user` (they were never enforced).
 * @param {import('knex').Knex} knex
 */
export async function up(knex) {
  await knex.schema.alterTable('users', (t) => {
    t.boolean('is_blocked').notNullable().defaultTo(false);
    t.boolean('is_demo').notNullable().defaultTo(false);
  });
  await knex('users').whereNot({ role: 'admin' }).update({ role: 'user' });
  await knex.schema.alterTable('users', (t) => {
    t.string('role', 16).notNullable().defaultTo('user').alter();
  });

  await knex.schema.createTable('announcements', (t) => {
    t.uuid('id').primary();
    t.string('title', 200).notNullable();
    t.text('body').notNullable();
    t.boolean('is_published').notNullable().defaultTo(false);
    t.bigInteger('published_at').nullable();
    t.uuid('author_id').nullable().references('id').inTable('users').onDelete('SET NULL');
    t.bigInteger('created_at').notNullable();
    t.bigInteger('updated_at').notNullable();
    t.index(['is_published', 'published_at']);
  });

  // Same reason as 20261026000002_enable_rls: hide the table from Supabase's REST API.
  if (knex.client.config.client === 'pg') {
    await knex.raw('ALTER TABLE ?? ENABLE ROW LEVEL SECURITY', ['public.announcements']);
  }
}

/** @param {import('knex').Knex} knex */
export async function down(knex) {
  await knex.schema.dropTableIfExists('announcements');
  await knex('users').where({ role: 'user' }).update({ role: 'student' });
  await knex.schema.alterTable('users', (t) => {
    t.string('role', 16).notNullable().defaultTo('student').alter();
  });
  await knex.schema.alterTable('users', (t) => {
    t.dropColumn('is_blocked');
    t.dropColumn('is_demo');
  });
}
