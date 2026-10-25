/**
 * LMS data imported on the device (courses + grades, events, course materials).
 * Rows are private to the user and synced like subjects (LWW on `updated_at`,
 * incremental pulls by `server_updated_at`, soft delete via `is_deleted`).
 * `lms_*_id` are Moodle integer ids (null for manually added rows).
 * @param {import('knex').Knex} knex
 */
export async function up(knex) {
  await knex.schema.createTable('lms_courses', (t) => {
    t.uuid('id').primary();
    t.uuid('user_id').notNullable().references('id').inTable('users').onDelete('CASCADE');
    t.string('source', 8).notNullable().defaultTo('lms'); // lms | manual
    t.integer('lms_course_id').nullable();
    // No FK: ownership of the subject is checked explicitly in the sync service.
    t.uuid('subject_id').nullable();
    t.string('classification', 16).nullable(); // inprogress | past | future
    t.string('title', 255).notNullable();
    t.string('teacher_name', 160).nullable();
    t.integer('credits').notNullable().defaultTo(5);
    t.double('register_midterm').nullable();
    t.double('register_endterm').nullable();
    t.double('final_exam').nullable();
    t.double('total').nullable();
    t.text('grade_items_json').nullable();
    t.bigInteger('imported_at').nullable();
    t.boolean('is_deleted').notNullable().defaultTo(false);
    t.bigInteger('updated_at').notNullable();
    t.bigInteger('server_updated_at').notNullable();
    t.index(['user_id', 'server_updated_at']);
  });

  await knex.schema.createTable('lms_events', (t) => {
    t.uuid('id').primary();
    t.uuid('user_id').notNullable().references('id').inTable('users').onDelete('CASCADE');
    t.integer('lms_event_id').nullable();
    t.integer('lms_course_id').nullable();
    t.string('title', 255).notNullable();
    t.string('course_title', 255).nullable();
    t.string('event_type', 16).notNullable().defaultTo('other'); // deadline | class | other
    t.string('module_name', 64).nullable(); // assign, quiz, attendance, ...
    t.bigInteger('starts_at').notNullable(); // epoch ms; due time for deadlines
    t.integer('duration_min').nullable();
    t.string('location', 128).nullable();
    t.string('url', 1024).nullable();
    t.boolean('is_done').notNullable().defaultTo(false);
    t.bigInteger('imported_at').nullable();
    t.boolean('is_deleted').notNullable().defaultTo(false);
    t.bigInteger('updated_at').notNullable();
    t.bigInteger('server_updated_at').notNullable();
    t.index(['user_id', 'server_updated_at']);
  });

  await knex.schema.createTable('lms_materials', (t) => {
    t.uuid('id').primary();
    t.uuid('user_id').notNullable().references('id').inTable('users').onDelete('CASCADE');
    t.integer('lms_module_id').nullable();
    t.integer('lms_course_id').nullable();
    t.string('course_title', 255).nullable();
    t.string('section_title', 255).nullable();
    t.string('title', 255).notNullable();
    t.string('material_type', 16).notNullable().defaultTo('other'); // file | folder | url | page | other
    t.string('url', 1024).nullable();
    t.bigInteger('imported_at').nullable();
    t.boolean('is_deleted').notNullable().defaultTo(false);
    t.bigInteger('updated_at').notNullable();
    t.bigInteger('server_updated_at').notNullable();
    t.index(['user_id', 'server_updated_at']);
  });
}

/** @param {import('knex').Knex} knex */
export async function down(knex) {
  await knex.schema.dropTableIfExists('lms_materials');
  await knex.schema.dropTableIfExists('lms_events');
  await knex.schema.dropTableIfExists('lms_courses');
}
