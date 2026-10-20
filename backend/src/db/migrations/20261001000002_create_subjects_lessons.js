/**
 * subjects + lessons.
 *
 * Sync columns:
 *  - `updated_at`        client clock (ms) of the last edit -> used for Last-Write-Wins.
 *  - `server_updated_at` server clock (ms) when the row was last written on the server ->
 *                        monotonic cursor for incremental pulls (`lastSyncedAt`).
 *  - `is_deleted`        soft-delete tombstone so deletions propagate to other devices.
 * `sync_status` exists only in the client SQLite DB.
 * @param {import('knex').Knex} knex
 */
export async function up(knex) {
  await knex.schema.createTable('subjects', (t) => {
    t.uuid('id').primary();
    t.uuid('user_id').notNullable().references('id').inTable('users').onDelete('CASCADE');
    t.string('title', 160).notNullable();
    t.string('teacher_name', 160).nullable();
    t.string('color_hex', 9).nullable();
    t.boolean('is_deleted').notNullable().defaultTo(false);
    t.bigInteger('updated_at').notNullable();
    t.bigInteger('server_updated_at').notNullable();
    t.index(['user_id', 'server_updated_at']);
  });

  await knex.schema.createTable('lessons', (t) => {
    t.uuid('id').primary();
    t.uuid('subject_id').notNullable().references('id').inTable('subjects').onDelete('CASCADE');
    t.uuid('user_id').notNullable().references('id').inTable('users').onDelete('CASCADE');
    t.smallint('day_of_week').notNullable(); // 1 = Monday ... 7 = Sunday (ISO)
    t.string('start_time', 5).notNullable(); // HH:mm
    t.string('end_time', 5).notNullable(); // HH:mm
    t.string('classroom', 64).nullable();
    t.string('lesson_type', 16).notNullable().defaultTo('lecture'); // lecture | practice | lab
    t.string('topic', 255).nullable();
    t.boolean('is_even_week').nullable(); // null = every week
    t.string('specific_date', 10).nullable(); // YYYY-MM-DD one-off lesson / override
    t.string('valid_from', 10).nullable(); // YYYY-MM-DD (import ranges / archive)
    t.string('valid_to', 10).nullable();
    t.boolean('is_cancelled').notNullable().defaultTo(false);
    t.boolean('is_deleted').notNullable().defaultTo(false);
    t.bigInteger('updated_at').notNullable();
    t.bigInteger('server_updated_at').notNullable();
    t.index(['user_id', 'server_updated_at']);
  });
}

/** @param {import('knex').Knex} knex */
export async function down(knex) {
  await knex.schema.dropTableIfExists('lessons');
  await knex.schema.dropTableIfExists('subjects');
}
