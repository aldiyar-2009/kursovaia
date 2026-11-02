/**
 * College edition (SmartNation, college.smartnation.kz):
 *  - users.edition (`university` | `college`), users.sn_* — IIN/login, encrypted
 *    (AES-256-GCM) SmartNation credentials and the college group (e.g. ПО2501);
 *  - groups.sn_group_name — college group a student joins automatically;
 *  - sn_snapshots — cached grades/assignments snapshot (JSON text);
 *  - timetable_lessons — college timetable imported from Excel (data/timetables);
 *  - events — university events scraped from public Telegram channels.
 * Times are epoch milliseconds (BIGINT), dates 'YYYY-MM-DD', lesson times 'HH:mm'.
 * @param {import('knex').Knex} knex
 */
export async function up(knex) {
  await knex.schema.alterTable('users', (t) => {
    t.string('edition', 16).notNullable().defaultTo('university');
    t.string('sn_iin', 32).nullable().unique();
    t.text('sn_credentials_enc').nullable();
    t.string('sn_group', 32).nullable();
  });

  await knex.schema.alterTable('groups', (t) => {
    t.string('sn_group_name', 32).nullable().unique();
  });

  await knex.schema.createTable('sn_snapshots', (t) => {
    t.uuid('user_id').primary().references('id').inTable('users').onDelete('CASCADE');
    t.text('data').notNullable();
    t.bigInteger('synced_at').notNullable();
  });

  await knex.schema.createTable('timetable_lessons', (t) => {
    t.increments('id');
    t.string('group_name', 32).notNullable();
    t.integer('day_of_week').notNullable(); // 1 = Monday
    t.integer('pair_no').notNullable(); // 0 = "zero" pair of the afternoon shift
    t.string('start_time', 5).notNullable();
    t.string('end_time', 5).notNullable();
    t.string('subject', 150).notNullable();
    t.string('teacher', 150).nullable();
    t.string('room', 50).nullable();
    t.string('valid_from', 10).notNullable();
    t.string('valid_to', 10).nullable();
    t.string('source', 100).nullable();
    t.index(['group_name']);
  });

  await knex.schema.createTable('events', (t) => {
    t.increments('id');
    t.string('source', 64).notNullable(); // Telegram channel
    t.string('external_id', 64).notNullable(); // post id
    t.string('title', 200).notNullable();
    t.text('text').nullable();
    t.bigInteger('starts_at').notNullable();
    t.boolean('has_time').notNullable().defaultTo(false);
    t.string('place', 200).nullable();
    t.text('link').nullable();
    t.text('image_url').nullable();
    t.text('post_url').nullable();
    t.bigInteger('posted_at').notNullable();
    t.bigInteger('updated_at').notNullable();
    t.unique(['source', 'external_id']);
    t.index(['starts_at']);
  });

  // Same reason as 20261026000002_enable_rls: hide the tables from Supabase's REST API.
  if (knex.client.config.client === 'pg') {
    for (const table of ['sn_snapshots', 'timetable_lessons', 'events']) {
      // eslint-disable-next-line no-await-in-loop
      await knex.raw('ALTER TABLE ?? ENABLE ROW LEVEL SECURITY', [`public.${table}`]);
    }
  }
}

/** @param {import('knex').Knex} knex */
export async function down(knex) {
  await knex.schema.dropTableIfExists('events');
  await knex.schema.dropTableIfExists('timetable_lessons');
  await knex.schema.dropTableIfExists('sn_snapshots');
  await knex.schema.alterTable('groups', (t) => {
    t.dropUnique(['sn_group_name']);
    t.dropColumn('sn_group_name');
  });
  await knex.schema.alterTable('users', (t) => {
    t.dropUnique(['sn_iin']);
    t.dropColumn('edition');
    t.dropColumn('sn_iin');
    t.dropColumn('sn_credentials_enc');
    t.dropColumn('sn_group');
  });
}
