import './setup.js';
import assert from 'node:assert/strict';
import { after, before, describe, test } from 'node:test';
import { app, authed, db, registerUser, request, resetDb } from './helpers.js';

before(resetDb);
after(() => db.destroy());

describe('auth', () => {
  test('health endpoint', async () => {
    const res = await request(app).get('/api/health');
    assert.equal(res.status, 200);
    assert.equal(res.body.status, 'ok');
  });

  test('register -> login -> me', async () => {
    const reg = await request(app)
      .post('/api/auth/register')
      .send({ email: 'Anna@Test.dev', password: 'secret123', name: 'Анна' });
    assert.equal(reg.status, 201);
    assert.ok(reg.body.token);
    assert.equal(reg.body.user.email, 'anna@test.dev');
    assert.equal(reg.body.user.password_hash, undefined, 'hash must never leak');

    const login = await request(app).post('/api/auth/login').send({ email: 'anna@test.dev', password: 'secret123' });
    assert.equal(login.status, 200);

    const me = await authed(login.body.token).get('/api/auth/me');
    assert.equal(me.status, 200);
    assert.equal(me.body.user.name, 'Анна');
  });

  test('duplicate email -> 409, wrong password -> 401, bad input -> 400', async () => {
    const dup = await request(app).post('/api/auth/register').send({ email: 'anna@test.dev', password: 'secret123', name: 'X' });
    assert.equal(dup.status, 409);
    const wrong = await request(app).post('/api/auth/login').send({ email: 'anna@test.dev', password: 'nope' });
    assert.equal(wrong.status, 401);
    const bad = await request(app).post('/api/auth/register').send({ email: 'not-an-email', password: '1', name: '' });
    assert.equal(bad.status, 400);
  });

  test('protected routes require a valid token', async () => {
    assert.equal((await request(app).post('/api/sync').send({})).status, 401);
    assert.equal((await authed('garbage').get('/api/auth/me')).status, 401);
  });

  test('malformed JSON -> 400', async () => {
    const res = await request(app).post('/api/auth/login').set('Content-Type', 'application/json').send('{bad');
    assert.equal(res.status, 400);
    assert.equal(res.body.error.code, 'BAD_JSON');
  });
});

describe('groups', () => {
  test('creator gets no special role, invite code lets others join', async () => {
    const creator = await registerUser('Создатель');
    const created = await authed(creator.token).post('/api/groups').send({ title: 'ИВТ-21', semester: 3, semester_start: '2026-08-31' });
    assert.equal(created.status, 201);
    assert.equal(created.body.user.role, 'student');
    const code = created.body.group.invite_code;
    assert.match(code, /^[A-Z2-9]{6}$/);

    const student = await registerUser('Студент');
    const joined = await authed(student.token).post('/api/groups/join').send({ invite_code: code.toLowerCase() });
    assert.equal(joined.status, 200);
    assert.equal(joined.body.group.id, created.body.group.id);

    const members = await authed(student.token).get('/api/groups/me');
    assert.equal(members.body.members.length, 2);
  });

  test('any member can update semester_start', async () => {
    const creator = await registerUser('C');
    const g = await authed(creator.token).post('/api/groups').send({ title: 'SEM-1' });
    const member = await registerUser('M', { invite_code: g.body.group.invite_code });

    const res = await authed(member.token).patch('/api/groups/me').send({ semester_start: '2026-09-07', title: 'SEM-1a' });
    assert.equal(res.status, 200);
    assert.equal(res.body.group.semester_start, '2026-09-07');
    assert.equal(res.body.group.title, 'SEM-1a');

    const outsider = await registerUser('O');
    assert.equal((await authed(outsider.token).patch('/api/groups/me').send({ semester_start: '2026-09-07' })).status, 400);
  });

  test('GET /groups/me lists members by name', async () => {
    const zh = await registerUser('Жанна');
    const g = await authed(zh.token).post('/api/groups').send({ title: 'NAMES-1' });
    await registerUser('Борис', { invite_code: g.body.group.invite_code });
    await registerUser('Арман', { invite_code: g.body.group.invite_code });

    const res = await authed(zh.token).get('/api/groups/me');
    assert.equal(res.status, 200);
    assert.deepEqual(Object.keys(res.body).sort(), ['group', 'members']);
    assert.deepEqual(
      Object.keys(res.body.group).filter((k) => ['id', 'title', 'invite_code', 'semester_start'].includes(k)).sort(),
      ['id', 'invite_code', 'semester_start', 'title'],
    );
    assert.deepEqual(res.body.members.map((m) => m.name), ['Арман', 'Борис', 'Жанна']);
    for (const m of res.body.members) assert.deepEqual(Object.keys(m).sort(), ['id', 'name'], 'no email/role leak');

    const loner = await registerUser('Loner');
    const empty = await authed(loner.token).get('/api/groups/me');
    assert.deepEqual(empty.body, { group: null, members: [] });
  });

  test('register with invite code', async () => {
    const headman = await registerUser('H2');
    const g = await authed(headman.token).post('/api/groups').send({ title: 'ПИ-22' });
    const s = await registerUser('S2', { invite_code: g.body.group.invite_code });
    assert.equal(s.group.title, 'ПИ-22');
  });
});
