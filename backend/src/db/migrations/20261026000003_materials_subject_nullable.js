/**
 * A material may have no subject: `subject_code` / `subject_title` become nullable
 * instead of being filled with a made-up default subject.
 * `.alter()` works on PostgreSQL (ALTER COLUMN ... DROP NOT NULL) and on SQLite
 * (Knex rebuilds the table, keeping indexes).
 * @param {import('knex').Knex} knex
 */
export async function up(knex) {
  await knex.schema.alterTable('course_materials', (t) => {
    t.string('subject_code', 32).nullable().alter();
    t.string('subject_title', 120).nullable().alter();
  });
}

/** @param {import('knex').Knex} knex */
export async function down(knex) {
  await knex('course_materials').whereNull('subject_code').update({ subject_code: '' });
  await knex('course_materials').whereNull('subject_title').update({ subject_title: '' });
  await knex.schema.alterTable('course_materials', (t) => {
    t.string('subject_code', 32).notNullable().alter();
    t.string('subject_title', 120).notNullable().alter();
  });
}
