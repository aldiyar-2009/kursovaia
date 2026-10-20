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
  test('creator becomes headman, invite code lets others join as students', async () => {
    const headman = await registerUser('Староста');
    const created = await authed(headman.token).post('/api/groups').send({ title: 'ИВТ-21', semester: 3, semester_start: '2026-08-31' });
    assert.equal(created.status, 201);
    assert.equal(created.body.user.role, 'headman');
    const code = created.body.group.invite_code;
    assert.match(code, /^[A-Z2-9]{6}$/);

    const student = await registerUser('Студент');
    const joined = await authed(student.token).post('/api/groups/join').send({ invite_code: code.toLowerCase() });
    assert.equal(joined.status, 200);
    assert.equal(joined.body.user.role, 'student');
    assert.equal(joined.body.group.id, created.body.group.id);

    const members = await authed(student.token).get('/api/groups/me');
    assert.equal(members.body.members.length, 2);

    const forbidden = await authed(student.token).patch('/api/groups/me').send({ title: 'Hack' });
    assert.equal(forbidden.status, 403);
  });

  test('register with invite code', async () => {
    const headman = await registerUser('H2');
    const g = await authed(headman.token).post('/api/groups').send({ title: 'ПИ-22' });
    const s = await registerUser('S2', { invite_code: g.body.group.invite_code });
    assert.equal(s.group.title, 'ПИ-22');
  });
});
