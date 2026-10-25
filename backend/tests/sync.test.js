import './setup.js';
import assert from 'node:assert/strict';
import { after, before, describe, test } from 'node:test';
import { authed, db, registerUser, resetDb, uuid } from './helpers.js';

before(resetDb);
after(() => db.destroy());

const subject = (over = {}) => ({ id: uuid(), title: 'Базы данных', teacher_name: 'Петров', color_hex: '#6366F1', is_deleted: false, updated_at: 1000, ...over });
const lesson = (subjectId, over = {}) => ({
  id: uuid(), subject_id: subjectId, day_of_week: 1, start_time: '08:30', end_time: '10:00', classroom: '301',
  lesson_type: 'lecture', is_even_week: null, specific_date: null, is_cancelled: false, is_deleted: false, updated_at: 1000, ...over,
});

describe('POST /api/sync', () => {
  test('push creates rows, second device pulls them', async () => {
    const { token } = await registerUser('Device user');
    const s = subject();
    const l = lesson(s.id);
    const push = await authed(token).post('/api/sync').send({ last_synced_at: 0, changes: { subjects: [s], lessons: [l] } });
    assert.equal(push.status, 200);
    assert.deepEqual(push.body.applied.subjects, [s.id]);
    assert.deepEqual(push.body.applied.lessons, [l.id]);
    assert.equal(push.body.rejected.length, 0);
    assert.equal(push.body.changes.subjects.length, 0, 'own pushed rows are not echoed back');
    assert.ok(push.body.server_time > 0);

    const device2 = await authed(token).post('/api/sync').send({ last_synced_at: 0, changes: {} });
    assert.equal(device2.body.changes.subjects.length, 1);
    assert.equal(device2.body.changes.lessons[0].is_cancelled, false, 'booleans normalized');
    assert.equal(device2.body.changes.lessons[0].is_even_week, null);
  });

  test('Last-Write-Wins: newer client edit applies, stale edit is rejected and server copy returned', async () => {
    const { token } = await registerUser('LWW');
    const s = subject({ updated_at: 2000 });
    await authed(token).post('/api/sync').send({ changes: { subjects: [s] } });

    const newer = await authed(token).post('/api/sync').send({ changes: { subjects: [{ ...s, title: 'БД (new)', updated_at: 3000 }] } });
    assert.deepEqual(newer.body.applied.subjects, [s.id]);

    const stale = await authed(token).post('/api/sync').send({ last_synced_at: Date.now(), changes: { subjects: [{ ...s, title: 'old', updated_at: 2500 }] } });
    assert.equal(stale.body.applied.subjects.length, 0);
    assert.equal(stale.body.rejected[0].reason, 'stale');
    const returned = stale.body.changes.subjects.find((r) => r.id === s.id);
    assert.equal(returned.title, 'БД (new)', 'server wins and sends its copy');
  });

  test('soft delete propagates as tombstone, but is skipped on initial sync', async () => {
    const { token } = await registerUser('Deleter');
    const s = subject();
    const first = await authed(token).post('/api/sync').send({ changes: { subjects: [s] } });
    const cursor = first.body.server_time;
    await authed(token).post('/api/sync').send({ changes: { subjects: [{ ...s, is_deleted: true, updated_at: 5000 }] } });

    const incremental = await authed(token).post('/api/sync').send({ last_synced_at: cursor });
    assert.equal(incremental.body.changes.subjects[0].is_deleted, true);
    const initial = await authed(token).post('/api/sync').send({ last_synced_at: 0 });
    assert.equal(initial.body.changes.subjects.length, 0);
  });

  test('cannot touch other users rows or reference foreign subjects', async () => {
    const a = await registerUser('A');
    const b = await registerUser('B');
    const s = subject();
    await authed(a.token).post('/api/sync').send({ changes: { subjects: [s] } });

    const hijack = await authed(b.token).post('/api/sync').send({ changes: { subjects: [{ ...s, title: 'mine', updated_at: 9999 }] } });
    assert.equal(hijack.body.rejected[0].reason, 'forbidden');
    const foreignRef = await authed(b.token).post('/api/sync').send({ changes: { lessons: [lesson(s.id)] } });
    assert.equal(foreignRef.body.rejected[0].reason, 'subject_id not found');
  });

  test('invalid records are rejected individually, valid ones still apply', async () => {
    const { token } = await registerUser('Validator');
    const good = subject();
    const res = await authed(token).post('/api/sync').send({
      changes: { subjects: [good, { id: 'nope', title: 'x', updated_at: 1 }, subject({ title: '' })] },
    });
    assert.equal(res.status, 200);
    assert.deepEqual(res.body.applied.subjects, [good.id]);
    assert.equal(res.body.rejected.length, 2);
  });

  test('bad payload shape -> 400', async () => {
    const { token } = await registerUser('Shape');
    assert.equal((await authed(token).post('/api/sync').send({ changes: { subjects: 'x' } })).status, 400);
    assert.equal((await authed(token).post('/api/sync').send({ last_synced_at: -5 })).status, 400);
  });

  test('group tasks: only headman can publish, students receive them', async () => {
    const headman = await registerUser('Headman');
    const g = await authed(headman.token).post('/api/groups').send({ title: 'G-1' });
    const student = await registerUser('Student', { invite_code: g.body.group.invite_code });

    const studentTask = { id: uuid(), title: 'Fake group task', priority: 1, status: 'inbox', is_group: true, is_deleted: false, updated_at: 1 };
    await authed(student.token).post('/api/sync').send({ changes: { tasks: [studentTask] } });
    const row = await db('tasks').where({ id: studentTask.id }).first();
    assert.equal(Boolean(row.is_group), false, 'student cannot publish group tasks');

    const groupTask = { id: uuid(), title: 'Лаба №3', priority: 1, status: 'inbox', is_group: true, due_date: Date.now() + 86400000, is_deleted: false, updated_at: 1 };
    await authed(headman.token).post('/api/sync').send({ changes: { tasks: [groupTask] } });

    const pull = await authed(student.token).post('/api/sync').send({ last_synced_at: 0 });
    const received = pull.body.changes.tasks.find((t) => t.id === groupTask.id);
    assert.ok(received, 'student receives group task');
    assert.equal(received.is_group, true);
    assert.equal(received.group_id, g.body.group.id);

    const edit = await authed(student.token).post('/api/sync').send({ changes: { tasks: [{ ...groupTask, title: 'hacked', updated_at: 99 }] } });
    assert.equal(edit.body.rejected[0].reason, 'forbidden');
  });

  test('subtasks require own parent task', async () => {
    const { token } = await registerUser('Subtasker');
    const task = { id: uuid(), title: 'Курсовая', priority: 2, status: 'in_progress', is_group: false, is_deleted: false, updated_at: 1 };
    const sub = { id: uuid(), task_id: task.id, title: 'Введение', is_done: false, position: 0, is_deleted: false, updated_at: 1 };
    const orphan = { ...sub, id: uuid(), task_id: uuid() };
    const res = await authed(token).post('/api/sync').send({ changes: { tasks: [task], subtasks: [sub, orphan] } });
    assert.deepEqual(res.body.applied.subtasks, [sub.id]);
    assert.equal(res.body.rejected[0].reason, 'task_id not found');
  });

  test('chat is gone: pushed chat_messages are ignored and nothing is returned for them', async () => {
    const user = await registerUser('NoChat');
    await authed(user.token).post('/api/groups').send({ title: 'NoChat-1' });

    const m = { id: uuid(), message_type: 'text', content: 'От старого клиента', created_at: Date.now() };
    const res = await authed(user.token).post('/api/sync').send({ last_synced_at: 0, changes: { chat_messages: [m] } });
    assert.equal(res.status, 200);
    assert.equal(res.body.changes.chat_messages, undefined, 'no chat in the pull');
    assert.equal(res.body.applied.chat_messages, undefined, 'no chat in applied');
    assert.equal(res.body.rejected.length, 0);
    assert.equal((await db('chat_messages').where({ id: m.id })).length, 0, 'nothing stored');
  });
});
