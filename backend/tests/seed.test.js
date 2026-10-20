import './setup.js';
import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { app, authed, db, request, resetDb } from './helpers.js';

before(async () => {
  await resetDb();
  await db.seed.run();
});
after(() => db.destroy());

test('demo seed: both accounts log in and get timetable, deadlines and chat', async () => {
  for (const email of ['headman@studyplan.dev', 'student@studyplan.dev']) {
    // eslint-disable-next-line no-await-in-loop
    const login = await request(app).post('/api/auth/login').send({ email, password: 'password123' });
    assert.equal(login.status, 200, email);
    assert.equal(login.body.group.title, 'ИВТ-21');
    // eslint-disable-next-line no-await-in-loop
    const sync = await authed(login.body.token).post('/api/sync').send({ last_synced_at: 0 });
    assert.equal(sync.body.changes.subjects.length, 6);
    assert.ok(sync.body.changes.lessons.length >= 15);
    assert.ok(sync.body.changes.tasks.some((t) => t.is_group));
    assert.ok(sync.body.changes.chat_messages.some((m) => m.message_type === 'schedule_update'));
  }
});
