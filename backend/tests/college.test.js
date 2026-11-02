import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { app, authed, db, registerUser, request, resetDb } from './helpers.js';
import { SmartNationClient } from '../src/services/smartnation/client.js';
import { setClientFactory } from '../src/services/smartnation/sessions.js';
import { importAll } from '../src/services/timetable.service.js';
import { startFakeSmartNation } from './fake-smartnation.js';

const IIN = '090204550001';
const IIN2 = '090204550002';
const PASSWORD = `pw-${IIN}`;

const snLogin = (login, password) => request(app).post('/api/auth/smartnation').send({ login, password });

describe('college edition API', () => {
  let fake;
  const useFake = () => setClientFactory((opts) => new SmartNationClient({ ...opts, baseUrl: fake.baseUrl }));

  before(async () => {
    await resetDb();
    fake = await startFakeSmartNation({ group: 'ПО2406' });
    useFake();
  });
  after(async () => {
    fake.close();
    setClientFactory(null);
    await db.destroy();
  });

  test('POST /auth/smartnation creates a college user and its college group', async () => {
    const res = await snLogin(IIN, PASSWORD);
    assert.equal(res.status, 200, JSON.stringify(res.body));
    assert.ok(res.body.token);
    assert.equal(res.body.user.edition, 'college');
    assert.equal(res.body.user.sn_group, 'ПО2406');
    assert.equal(res.body.user.name, 'Студент 0001');
    assert.equal(res.body.user.email, null);
    assert.equal(res.body.group.sn_group_name, 'ПО2406');
    assert.equal(res.body.group.title, 'ПО2406');
    assert.equal(res.body.group.semester_start, '2026-09-01');
    assert.match(res.body.group.invite_code, /^[A-Z0-9]{6}$/);
    assert.equal(res.body.user.group_id, res.body.group.id);

    const stored = await db('users').where({ sn_iin: IIN }).first();
    assert.ok(stored.sn_credentials_enc);
    assert.ok(!stored.sn_credentials_enc.includes(PASSWORD));
  });

  test('second login returns the same user; a classmate joins the same group', async () => {
    const first = await snLogin(IIN, PASSWORD);
    const again = await snLogin(IIN, PASSWORD);
    assert.equal(again.status, 200);
    assert.equal(again.body.user.id, first.body.user.id);
    assert.equal((await db('users').where({ sn_iin: IIN })).length, 1);

    const mate = await snLogin(IIN2, `pw-${IIN2}`);
    assert.equal(mate.status, 200);
    assert.notEqual(mate.body.user.id, first.body.user.id);
    assert.equal(mate.body.group.id, first.body.group.id);
    assert.equal((await db('groups').where({ sn_group_name: 'ПО2406' })).length, 1);
  });

  test('wrong password -> 401 SN_INVALID_CREDENTIALS, empty fields -> 400', async () => {
    const wrong = await snLogin(IIN, 'nope');
    assert.equal(wrong.status, 401);
    assert.equal(wrong.body.error.code, 'SN_INVALID_CREDENTIALS');
    assert.equal((await snLogin('', 'x')).status, 400);
    assert.equal((await snLogin(IIN, '')).status, 400);
  });

  test('SmartNation down -> 502 SN_UNAVAILABLE', async () => {
    setClientFactory((opts) => new SmartNationClient({ ...opts, baseUrl: 'http://127.0.0.1:1' }));
    try {
      const res = await snLogin(IIN, PASSWORD);
      assert.equal(res.status, 502);
      assert.equal(res.body.error.code, 'SN_UNAVAILABLE');
    } finally {
      useFake();
    }
  });

  test('blocked college user gets USER_BLOCKED', async () => {
    const login = '090204550009';
    await snLogin(login, `pw-${login}`);
    await db('users').where({ sn_iin: login }).update({ is_blocked: true });
    const res = await snLogin(login, `pw-${login}`);
    assert.equal(res.status, 403);
    assert.equal(res.body.error.code, 'USER_BLOCKED');
  });

  test('GET /college/snapshot returns grades and assignments; refresh is throttled', async () => {
    const { body } = await snLogin(IIN, PASSWORD);
    const res = await authed(body.token).get('/api/college/snapshot');
    assert.equal(res.status, 200);
    const { snapshot } = res.body;
    assert.equal(snapshot.profile.group, 'ПО2406');
    assert.equal(snapshot.subjects[0].average, 95);
    assert.equal(snapshot.stats.absences, 1);
    assert.ok(snapshot.assignments.some((a) => a.is_current));

    const refreshed = await authed(body.token).post('/api/college/refresh');
    assert.equal(refreshed.status, 200);
    assert.equal(refreshed.body.snapshot.synced_at, snapshot.synced_at); // < 60 s: the cached one
  });

  test('university users get 403 NOT_COLLEGE', async () => {
    const user = await registerUser('Uni');
    assert.equal(user.user.edition, 'university');
    for (const res of [
      await authed(user.token).get('/api/college/snapshot'),
      await authed(user.token).post('/api/college/refresh'),
    ]) {
      assert.equal(res.status, 403);
      assert.equal(res.body.error.code, 'NOT_COLLEGE');
    }
  });

  test('SmartNation credentials never appear in responses', async () => {
    const login = await snLogin(IIN, PASSWORD);
    const { token } = login.body;
    const responses = [
      login,
      await authed(token).get('/api/auth/me'),
      await authed(token).get('/api/groups/me'),
      await authed(token).get('/api/college/snapshot'),
      await authed(token).patch('/api/auth/me').send({ name: 'Новое имя' }),
    ];
    for (const res of responses) {
      const text = JSON.stringify(res.body);
      assert.ok(!text.includes(PASSWORD), `${res.req.path} leaks the password`);
      assert.ok(!text.includes('sn_credentials_enc'), `${res.req.path} leaks encrypted credentials`);
      assert.ok(!text.includes('password_hash'));
    }
    assert.equal(responses[1].body.user.edition, 'college');
    assert.equal(responses[1].body.user.sn_group, 'ПО2406');
  });

  test('college demo: stored snapshot, tasks, no LMS rows; never contacts SmartNation', async () => {
    await importAll(db);
    setClientFactory(() => {
      throw new Error('demo must not contact SmartNation');
    });
    try {
      const res = await request(app).post('/api/auth/demo').send({ edition: 'college' });
      assert.equal(res.status, 201);
      assert.equal(res.body.user.edition, 'college');
      assert.equal(res.body.user.is_demo, true);
      assert.equal(res.body.user.sn_group, 'ПО2501');
      assert.equal(res.body.group.sn_group_name, null);

      const { token } = res.body;
      const snap = (await authed(token).get('/api/college/snapshot')).body.snapshot;
      assert.equal(snap.profile.group, 'ПО2501');
      assert.ok(snap.subjects.length >= 4 && snap.subjects.length <= 6);
      assert.ok(snap.subjects.every((s) => s.grades.every((g) => /^2026-(09|10)-\d{2}$/.test(g.date) && g.theme)));
      assert.ok(snap.stats.absences >= 2);
      assert.equal(snap.stats.subjects_at_risk.length, 1);
      assert.ok(snap.assignments.some((a) => a.is_current));
      assert.ok(snap.assignments.some((a) => a.closed && a.result != null));

      const refreshed = await authed(token).post('/api/college/refresh');
      assert.equal(refreshed.status, 200);
      assert.deepEqual(refreshed.body.snapshot, snap);

      const pulled = await authed(token).post('/api/sync').send({ last_synced_at: 0, changes: {} });
      assert.ok(pulled.body.changes.tasks.length >= 3);
      assert.ok(pulled.body.changes.tasks.some((t) => t.is_group));
      assert.deepEqual(pulled.body.changes.lms_courses, []);
      assert.deepEqual(pulled.body.changes.lms_events, []);

      // The demo group exists in the public timetable.
      const tt = await request(app).get('/api/timetable').query({ group: res.body.user.sn_group });
      assert.equal(tt.status, 200);
      assert.ok(tt.body.lessons.length > 0);

      const reset = await authed(token).post('/api/auth/demo/reset');
      assert.equal(reset.status, 200);
      assert.equal(await db('sn_snapshots').where({ user_id: res.body.user.id }).first(), undefined);
    } finally {
      useFake();
    }
  });

  test('university demo is unchanged; unknown edition -> 400', async () => {
    const uni = await request(app).post('/api/auth/demo');
    assert.equal(uni.status, 201);
    assert.equal(uni.body.user.edition, 'university');
    assert.equal((await request(app).post('/api/auth/demo').send({ edition: 'school' })).status, 400);
  });
});
