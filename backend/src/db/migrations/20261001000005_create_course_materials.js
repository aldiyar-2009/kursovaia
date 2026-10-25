/**
 * course_materials table for storing university files and study materials.
 * @param {import('knex').Knex} knex
 */
export async function up(knex) {
  await knex.schema.createTable('course_materials', (t) => {
    t.uuid('id').primary();
    t.uuid('group_id').notNullable().references('id').inTable('groups').onDelete('CASCADE');
    t.uuid('uploader_id').notNullable().references('id').inTable('users').onDelete('CASCADE');
    t.string('uploader_name', 120).notNullable();
    t.string('subject_code', 32).notNullable(); // py, math, ict, discrete, eng, hist, pe
    t.string('subject_title', 120).notNullable();
    t.string('title', 200).notNullable();
    t.text('description').nullable();
    t.string('file_name', 255).notNullable();
    t.string('file_path', 255).notNullable(); // filename in uploadDir or virtual
    t.integer('file_size').notNullable().defaultTo(0);
    t.string('file_type', 16).notNullable().defaultTo('pdf'); // pdf, docx, zip, pptx
    t.string('category', 32).notNullable().defaultTo('lecture'); // syllabus, lecture, lab, assignment
    t.bigInteger('created_at').notNullable();
    t.bigInteger('updated_at').notNullable();

    t.index(['group_id', 'subject_code']);
    t.index(['group_id', 'created_at']);
  });
}

/** @param {import('knex').Knex} knex */
export async function down(knex) {
  await knex.schema.dropTableIfExists('course_materials');
}
