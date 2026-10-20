/**
 * chat_messages (group hub).
 * `payload_json` is JSONB on PostgreSQL and TEXT(JSON) on SQLite; the app always
 * writes a JSON string and parses it on read, so both behave the same.
 * @param {import('knex').Knex} knex
 */
export async function up(knex) {
  await knex.schema.createTable('chat_messages', (t) => {
    t.uuid('id').primary(); // generated on the client -> idempotent re-sends
    t.uuid('group_id').notNullable().references('id').inTable('groups').onDelete('CASCADE');
    t.uuid('sender_id').notNullable().references('id').inTable('users').onDelete('CASCADE');
    t.string('sender_name', 120).notNullable();
    t.string('message_type', 24).notNullable().defaultTo('text'); // text | schedule_update | homework | file
    t.text('content').notNullable();
    t.jsonb('payload_json').nullable();
    t.boolean('is_pinned').notNullable().defaultTo(false);
    t.bigInteger('created_at').notNullable(); // client time when the message was written
    t.bigInteger('server_updated_at').notNullable();
    t.index(['group_id', 'server_updated_at']);
    t.index(['group_id', 'created_at']);
  });
}

/** @param {import('knex').Knex} knex */
export async function down(knex) {
  await knex.schema.dropTableIfExists('chat_messages');
}
