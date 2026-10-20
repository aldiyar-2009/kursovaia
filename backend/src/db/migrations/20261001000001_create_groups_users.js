/**
 * groups + users.
 * Timestamps (`updated_at`, `created_at`) are epoch milliseconds (BIGINT) so the
 * values are identical in PostgreSQL, server-side SQLite and the client's Drift DB.
 * @param {import('knex').Knex} knex
 */
export async function up(knex) {
  await knex.schema.createTable('groups', (t) => {
    t.uuid('id').primary();
    t.string('title', 64).notNullable();
    t.string('invite_code', 16).notNullable().unique();
    t.integer('semester').notNullable().defaultTo(1);
    // Monday of the first study week (YYYY-MM-DD); used for odd/even week calculation.
    t.string('semester_start', 10).nullable();
    t.uuid('created_by').nullable();
    t.bigInteger('created_at').notNullable();
    t.bigInteger('updated_at').notNullable();
  });

  await knex.schema.createTable('users', (t) => {
    t.uuid('id').primary();
    t.string('email', 255).nullable().unique(); // nullable for guest accounts
    t.string('password_hash', 255).nullable();
    t.string('name', 120).notNullable();
    t.string('role', 16).notNullable().defaultTo('student'); // 'student' | 'headman'
    t.uuid('group_id').nullable().references('id').inTable('groups').onDelete('SET NULL');
    t.bigInteger('created_at').notNullable();
    t.bigInteger('updated_at').notNullable();
    t.index(['group_id']);
  });
}

/** @param {import('knex').Knex} knex */
export async function down(knex) {
  await knex.schema.dropTableIfExists('users');
  await knex.schema.dropTableIfExists('groups');
}
