import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { app, authed, db, registerUser, request, resetDb } from './helpers.js';

describe('demo accounts', () => {
  before(resetDb);
  after(() => db.destroy());

  test('POST /auth/demo creates a filled demo account with a group', async () => {
    const res = await request(app).post('/api/auth/demo');
    assert.equal(res.status, 201);
    assert.ok(res.body.token);
    assert.equal(res.body.user.is_demo, true);
    assert.equal(res.body.user.email, null);
    assert.ok(res.body.group?.invite_code);

    const pulled = await authed(res.body.token).post('/api/sync').send({ last_synced_at: 0, changes: {} });
    assert.equal(pulled.status, 200);
    const { changes } = pulled.body;
    assert.ok(changes.subjects.length >= 5);
    assert.ok(changes.lessons.length >= 10);
    assert.ok(changes.tasks.some((t) => t.is_group));
    assert.ok(changes.subtasks.length >= 1);
    assert.ok(changes.lms_courses.every((c) => c.register_midterm != null));
    assert.ok(changes.lms_events.length >= 1);

    const materials = await authed(res.body.token).get('/api/materials');
    assert.ok(materials.body.materials.length >= 1);
    const file = await authed(res.body.token).get(`/api/files/${materials.body.materials[0].file_path}`);
    assert.equal(file.status, 200);
  });

  test('demo data is a normal account: pushed rows are stored', async () => {
    const { body } = await request(app).post('/api/auth/demo');
    const id = crypto.randomUUID();
    const push = await authed(body.token).post('/api/sync').send({
      last_synced_at: 0,
      changes: { tasks: [{ id, title: 'My own task', priority: 2, status: 'inbox', updated_at: Date.now() }] },
    });
    assert.equal(push.status, 200);
    assert.ok(await db('tasks').where({ id, user_id: body.user.id }).first());
  });

  test('reset tombstones all demo rows and removes materials', async () => {
    const { body } = await request(app).post('/api/auth/demo');
    const reset = await authed(body.token).post('/api/auth/demo/reset');
    assert.equal(reset.status, 200);

    const pulled = await authed(body.token).post('/api/sync').send({ last_synced_at: 0, changes: {} });
    for (const table of ['subjects', 'lessons', 'tasks', 'lms_courses', 'lms_events']) {
      assert.ok(pulled.body.changes[table].every((r) => r.is_deleted), `${table} tombstoned`);
    }
    assert.deepEqual((await authed(body.token).get('/api/materials')).body.materials, []);
  });

  test('regular accounts cannot be reset', async () => {
    const user = await registerUser('Real');
    const res = await authed(user.token).post('/api/auth/demo/reset');
    assert.equal(res.status, 403);
  });
});
