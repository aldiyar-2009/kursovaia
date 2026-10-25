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

  describe('joining a group pulls tasks published before joining', () => {
    async function setup() {
      const author = await registerUser('Author');
      const g = await authed(author.token).post('/api/groups').send({ title: `JOIN-${uuid().slice(0, 6)}` });
      const groupId = g.body.group.id;
      const old = { id: uuid(), title: 'Старая групповая', priority: 2, status: 'inbox', is_group: true, group_id: groupId, is_deleted: false, updated_at: 1 };
      const gone = { id: uuid(), title: 'Удалённая', priority: 2, status: 'inbox', is_group: true, group_id: groupId, is_deleted: true, updated_at: 1 };
      const personal = { id: uuid(), title: 'Личная автора', priority: 2, status: 'inbox', is_group: false, is_deleted: false, updated_at: 1 };
      const push = await authed(author.token).post('/api/sync').send({ changes: { tasks: [old, gone, personal] } });
      assert.equal(push.body.applied.tasks.length, 3);

      // The newcomer synced before joining: their cursor is already past the publication.
      const newcomer = await registerUser('Newcomer');
      const first = await authed(newcomer.token).post('/api/sync').send({ last_synced_at: 0 });
      const cursor = first.body.server_time + 60_000;
      const join = await authed(newcomer.token).post('/api/groups/join').send({ invite_code: g.body.group.invite_code });
      assert.equal(join.status, 200);
      return { newcomer, cursor, old, gone, personal };
    }

    test('incremental sync with the old cursor does not see them (the bug clients work around)', async () => {
      const { newcomer, cursor, old } = await setup();
      const res = await authed(newcomer.token).post('/api/sync').send({ last_synced_at: cursor });
      assert.ok(!res.body.changes.tasks.some((t) => t.id === old.id));
    });

    test('after joining a group, a sync with last_synced_at=0 returns tasks published before joining', async () => {
      const { newcomer, old, gone, personal } = await setup();
      const res = await authed(newcomer.token).post('/api/sync').send({ last_synced_at: 0 });
      const ids = res.body.changes.tasks.map((t) => t.id);
      assert.ok(ids.includes(old.id), 'old group task is pulled');
      assert.ok(!ids.includes(gone.id), 'deleted group tasks are not sent on a full pull');
      assert.ok(!ids.includes(personal.id), "the author's personal tasks stay private");
    });

    test('full_group_pull: true returns all live group tasks even with a non-zero cursor', async () => {
      const { newcomer, cursor, old, gone, personal } = await setup();
      const res = await authed(newcomer.token).post('/api/sync').send({ last_synced_at: cursor, full_group_pull: true });
      assert.equal(res.status, 200);
      const ids = res.body.changes.tasks.map((t) => t.id);
      assert.ok(ids.includes(old.id));
      assert.ok(!ids.includes(gone.id));
      assert.ok(!ids.includes(personal.id));
    });
  });

  test('student member can publish group task', async () => {
    const creator = await registerUser('Creator');
    const g = await authed(creator.token).post('/api/groups').send({ title: 'G-1' });
    const groupId = g.body.group.id;
    const student = await registerUser('Student', { invite_code: g.body.group.invite_code });
    assert.equal(student.user.role, 'student');

    const groupTask = {
      id: uuid(), title: 'Лаба №3', priority: 1, status: 'inbox', is_group: true, group_id: groupId,
      due_date: Date.now() + 86400000, is_deleted: false, updated_at: 1,
    };
    const push = await authed(student.token).post('/api/sync').send({ changes: { tasks: [groupTask] } });
    assert.deepEqual(push.body.applied.tasks, [groupTask.id]);

    const pull = await authed(creator.token).post('/api/sync').send({ last_synced_at: 0 });
    const received = pull.body.changes.tasks.find((t) => t.id === groupTask.id);
    assert.ok(received, 'other members receive the group task');
    assert.equal(received.is_group, true);
    assert.equal(received.group_id, groupId);

    const edit = await authed(creator.token).post('/api/sync').send({ changes: { tasks: [{ ...groupTask, title: 'hacked', updated_at: 99 }] } });
    assert.equal(edit.body.rejected[0].reason, 'forbidden', 'only the author edits a group task');
  });

  test('non-member cannot publish group task for another group', async () => {
    const a = await registerUser('Owner A');
    const ga = await authed(a.token).post('/api/groups').send({ title: 'G-A' });
    const b = await registerUser('Owner B');
    await authed(b.token).post('/api/groups').send({ title: 'G-B' });
    const loner = await registerUser('No group');

    const foreign = { id: uuid(), title: 'Spam', priority: 3, status: 'inbox', is_group: true, group_id: ga.body.group.id, is_deleted: false, updated_at: 1 };
    const noGroup = { ...foreign, id: uuid() };
    const noGroupId = { id: uuid(), title: 'No group_id', priority: 3, status: 'inbox', is_group: true, is_deleted: false, updated_at: 1 };
    await authed(b.token).post('/api/sync').send({ changes: { tasks: [foreign, noGroupId] } });
    await authed(loner.token).post('/api/sync').send({ changes: { tasks: [noGroup] } });

    for (const id of [foreign.id, noGroup.id, noGroupId.id]) {
      // eslint-disable-next-line no-await-in-loop
      const row = await db('tasks').where({ id }).first();
      assert.equal(Boolean(row.is_group), false);
      assert.equal(row.group_id, null);
    }
    const pullA = await authed(a.token).post('/api/sync').send({ last_synced_at: 0 });
    assert.equal(pullA.body.changes.tasks.length, 0, 'group A sees nothing from outsiders');
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

const lmsCourse = (over = {}) => ({
  id: uuid(), source: 'lms', lms_course_id: 4211, subject_id: null, classification: 'inprogress',
  title: 'Linear Algebra | Иванов И.И.', teacher_name: 'Иванов И.И.', credits: 5,
  register_midterm: 78.5, register_endterm: null, final_exam: null, total: null,
  grade_items_json: JSON.stringify([{ name: 'Quiz 1', grade: '8,00' }]), imported_at: 1_700_000_000_000,
  is_deleted: false, updated_at: 1000, ...over,
});
const lmsEvent = (over = {}) => ({
  id: uuid(), lms_event_id: 99001, lms_course_id: 4211, title: 'Assignment 2 is due', course_title: 'Linear Algebra',
  event_type: 'deadline', module_name: 'assign', starts_at: 1_800_000_000_000, duration_min: null, location: null,
  url: 'https://lms.astanait.edu.kz/mod/assign/view.php?id=1', is_done: false, imported_at: 1_700_000_000_000,
  is_deleted: false, updated_at: 1000, ...over,
});
const lmsMaterial = (over = {}) => ({
  id: uuid(), lms_module_id: 555, lms_course_id: 4211, course_title: 'Linear Algebra', section_title: 'Week 1',
  title: 'Lecture 1 slides', material_type: 'file', url: 'https://lms.astanait.edu.kz/mod/resource/view.php?id=555',
  imported_at: 1_700_000_000_000, is_deleted: false, updated_at: 1000, ...over,
});

describe('POST /api/sync — LMS tables', () => {
  test('response contains exactly the SYNC_ORDER tables', async () => {
    const { token } = await registerUser('Keys');
    const res = await authed(token).post('/api/sync').send({ last_synced_at: 0 });
    assert.deepEqual(
      Object.keys(res.body.changes),
      ['subjects', 'lessons', 'tasks', 'subtasks', 'lms_courses', 'lms_events', 'lms_materials'],
    );
  });

  test('push + pull round-trip for lms_courses, lms_events, lms_materials', async () => {
    const { token } = await registerUser('LMS user');
    const s = subject();
    const c = lmsCourse({ subject_id: s.id });
    const manual = lmsCourse({ source: 'manual', lms_course_id: null, classification: null, title: 'Physics (manual)', credits: undefined, grade_items_json: null, imported_at: null });
    delete manual.credits;
    const e = lmsEvent();
    const cls = lmsEvent({ lms_event_id: 99002, event_type: 'class', module_name: 'attendance', duration_min: 50, location: 'C1.2.204', is_done: true });
    const m = lmsMaterial();

    const push = await authed(token).post('/api/sync').send({
      last_synced_at: 0,
      changes: { subjects: [s], lms_courses: [c, manual], lms_events: [e, cls], lms_materials: [m] },
    });
    assert.equal(push.status, 200);
    assert.deepEqual(push.body.rejected, []);
    assert.deepEqual(push.body.applied.lms_courses, [c.id, manual.id]);
    assert.deepEqual(push.body.applied.lms_events, [e.id, cls.id]);
    assert.deepEqual(push.body.applied.lms_materials, [m.id]);

    const pull = await authed(token).post('/api/sync').send({ last_synced_at: 0 });
    const gotC = pull.body.changes.lms_courses.find((r) => r.id === c.id);
    assert.equal(gotC.subject_id, s.id);
    assert.equal(gotC.register_midterm, 78.5);
    assert.equal(gotC.total, null);
    assert.equal(gotC.lms_course_id, 4211);
    assert.equal(gotC.grade_items_json, c.grade_items_json);
    assert.equal(gotC.is_deleted, false);
    assert.equal(pull.body.changes.lms_courses.find((r) => r.id === manual.id).credits, 5, 'credits default 5');

    const gotCls = pull.body.changes.lms_events.find((r) => r.id === cls.id);
    assert.equal(gotCls.event_type, 'class');
    assert.equal(gotCls.duration_min, 50);
    assert.equal(gotCls.is_done, true, 'booleans normalized');
    assert.equal(pull.body.changes.lms_events.find((r) => r.id === e.id).is_done, false);

    const gotM = pull.body.changes.lms_materials[0];
    assert.equal(gotM.material_type, 'file');
    assert.equal(gotM.section_title, 'Week 1');

    const other = await registerUser('Other');
    const otherPull = await authed(other.token).post('/api/sync').send({ last_synced_at: 0 });
    assert.equal(otherPull.body.changes.lms_courses.length, 0, 'LMS rows are private');
    assert.equal(otherPull.body.changes.lms_events.length, 0);
    assert.equal(otherPull.body.changes.lms_materials.length, 0);
    const hijack = await authed(other.token).post('/api/sync').send({ changes: { lms_events: [{ ...e, is_done: true, updated_at: 5000 }] } });
    assert.equal(hijack.body.rejected[0].reason, 'forbidden');
  });

  test('validation rejects total 101, unknown event_type and foreign subject_id', async () => {
    const a = await registerUser('Validator A');
    const b = await registerUser('Validator B');
    const foreignSubject = subject();
    await authed(a.token).post('/api/sync').send({ changes: { subjects: [foreignSubject] } });

    const badTotal = lmsCourse({ total: 101 });
    const badCredits = lmsCourse({ credits: 0 });
    const foreignRef = lmsCourse({ subject_id: foreignSubject.id });
    const badEvent = lmsEvent({ event_type: 'x' });
    const noStart = lmsEvent({ starts_at: null });
    const badMaterial = lmsMaterial({ material_type: 'video' });

    const res = await authed(b.token).post('/api/sync').send({
      changes: { lms_courses: [badTotal, badCredits, foreignRef], lms_events: [badEvent, noStart], lms_materials: [badMaterial] },
    });
    assert.equal(res.status, 200);
    assert.deepEqual(res.body.applied.lms_courses, []);
    assert.deepEqual(res.body.applied.lms_events, []);
    assert.deepEqual(res.body.applied.lms_materials, []);
    const reasons = Object.fromEntries(res.body.rejected.map((r) => [r.id, r.reason]));
    assert.match(reasons[badTotal.id], /total/);
    assert.match(reasons[badCredits.id], /credits/);
    assert.equal(reasons[foreignRef.id], 'subject_id not found');
    assert.match(reasons[badEvent.id], /event_type/);
    assert.match(reasons[noStart.id], /starts_at/);
    assert.match(reasons[badMaterial.id], /material_type/);
  });

  test('Last-Write-Wins on lms_courses.credits', async () => {
    const { token } = await registerUser('LWW LMS');
    const c = lmsCourse({ updated_at: 2000 });
    await authed(token).post('/api/sync').send({ changes: { lms_courses: [c] } });

    const newer = await authed(token).post('/api/sync').send({ changes: { lms_courses: [{ ...c, credits: 6, updated_at: 3000 }] } });
    assert.deepEqual(newer.body.applied.lms_courses, [c.id]);

    const stale = await authed(token).post('/api/sync').send({ last_synced_at: Date.now(), changes: { lms_courses: [{ ...c, credits: 3, updated_at: 2500 }] } });
    assert.equal(stale.body.rejected[0].reason, 'stale');
    assert.equal(stale.body.changes.lms_courses.find((r) => r.id === c.id).credits, 6, 'server copy wins');
  });
});
