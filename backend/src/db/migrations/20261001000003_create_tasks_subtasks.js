/**
 * tasks (deadlines) + subtasks (checklist items).
 * @param {import('knex').Knex} knex
 */
export async function up(knex) {
  await knex.schema.createTable('tasks', (t) => {
    t.uuid('id').primary();
    t.uuid('user_id').notNullable().references('id').inTable('users').onDelete('CASCADE');
    t.uuid('group_id').nullable().references('id').inTable('groups').onDelete('SET NULL');
    // No FK: a group task may reference the headman's subject that students don't own.
    t.uuid('subject_id').nullable();
    t.string('subject_title', 160).nullable(); // denormalised for group tasks
    t.string('title', 255).notNullable();
    t.text('description').nullable();
    t.bigInteger('due_date').nullable(); // epoch ms
    t.smallint('priority').notNullable().defaultTo(3); // 1 = P1 ... 3 = P3
    t.string('status', 16).notNullable().defaultTo('inbox'); // inbox | in_progress | completed
    t.boolean('is_group').notNullable().defaultTo(false);
    t.uuid('source_message_id').nullable(); // chat message the task was accepted from
    t.uuid('source_task_id').nullable(); // group task this personal copy was made from
    t.boolean('is_deleted').notNullable().defaultTo(false);
    t.bigInteger('updated_at').notNullable();
    t.bigInteger('server_updated_at').notNullable();
    t.index(['user_id', 'server_updated_at']);
    t.index(['group_id', 'is_group', 'server_updated_at']);
  });

  await knex.schema.createTable('subtasks', (t) => {
    t.uuid('id').primary();
    t.uuid('task_id').notNullable().references('id').inTable('tasks').onDelete('CASCADE');
    t.uuid('user_id').notNullable().references('id').inTable('users').onDelete('CASCADE');
    t.string('title', 255).notNullable();
    t.boolean('is_done').notNullable().defaultTo(false);
    t.integer('position').notNullable().defaultTo(0);
    t.boolean('is_deleted').notNullable().defaultTo(false);
    t.bigInteger('updated_at').notNullable();
    t.bigInteger('server_updated_at').notNullable();
    t.index(['user_id', 'server_updated_at']);
  });
}

/** @param {import('knex').Knex} knex */
export async function down(knex) {
  await knex.schema.dropTableIfExists('subtasks');
  await knex.schema.dropTableIfExists('tasks');
}
