import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { app, authed, db, registerUser, request, resetDb } from './helpers.js';

async function makeAdmin() {
  const admin = await registerUser('Admin');
  await db('users').where({ id: admin.user.id }).update({ role: 'admin' });
  return admin;
}

describe('admin panel API', () => {
  before(resetDb);
  after(() => db.destroy());

  test('only admins reach /api/admin', async () => {
    const user = await registerUser('Plain');
    const res = await authed(user.token).get('/api/admin/users');
    assert.equal(res.status, 403);
    assert.equal(res.body.error.code, 'FORBIDDEN');
    assert.equal((await request(app).get('/api/admin/users')).status, 401);
  });

  test('admin lists, creates and edits users; role is validated', async () => {
    const admin = await makeAdmin();
    const created = await authed(admin.token).post('/api/admin/users')
      .send({ email: 'New@Test.dev', password: 'secret123', name: 'New', role: 'user' });
    assert.equal(created.status, 201);
    assert.equal(created.body.user.email, 'new@test.dev');
    assert.equal(created.body.user.password_hash, undefined);

    const dup = await authed(admin.token).post('/api/admin/users')
      .send({ email: 'new@test.dev', password: 'secret123', name: 'Dup' });
    assert.equal(dup.status, 409);

    const bad = await authed(admin.token).patch(`/api/admin/users/${created.body.user.id}`).send({ role: 'god' });
    assert.equal(bad.status, 400);

    const edited = await authed(admin.token).patch(`/api/admin/users/${created.body.user.id}`)
      .send({ name: 'Renamed', role: 'admin' });
    assert.equal(edited.body.user.name, 'Renamed');
    assert.equal(edited.body.user.role, 'admin');

    const list = await authed(admin.token).get('/api/admin/users?q=renamed');
    assert.equal(list.status, 200);
    assert.deepEqual(list.body.users.map((u) => u.name), ['Renamed']);
  });

  test('admin cannot block or demote themselves', async () => {
    const admin = await makeAdmin();
    assert.equal((await authed(admin.token).post(`/api/admin/users/${admin.user.id}/block`)).status, 403);
    assert.equal((await authed(admin.token).patch(`/api/admin/users/${admin.user.id}`).send({ role: 'user' })).status, 403);
  });

  test('blocked user cannot log in or use the API until unblocked', async () => {
    const admin = await makeAdmin();
    await request(app).post('/api/auth/register').send({ email: 'victim@test.dev', password: 'secret123', name: 'V' });
    const login = await request(app).post('/api/auth/login').send({ email: 'victim@test.dev', password: 'secret123' });
    const { token, user } = login.body;

    const blocked = await authed(admin.token).post(`/api/admin/users/${user.id}/block`);
    assert.equal(blocked.body.user.is_blocked, true);

    const denied = await request(app).post('/api/auth/login').send({ email: 'victim@test.dev', password: 'secret123' });
    assert.equal(denied.status, 403);
    assert.equal(denied.body.error.code, 'USER_BLOCKED');
    assert.equal((await authed(token).get('/api/auth/me')).body.error.code, 'USER_BLOCKED');

    await authed(admin.token).post(`/api/admin/users/${user.id}/unblock`);
    assert.equal((await authed(token).get('/api/auth/me')).status, 200);
  });

  test('announcements: create, edit, publish, unpublish, delete; app sees only published', async () => {
    const admin = await makeAdmin();
    const user = await registerUser('Reader');
    const created = await authed(admin.token).post('/api/admin/announcements').send({ title: 'Exam week', body: 'Starts Monday' });
    assert.equal(created.status, 201);
    const { id } = created.body.announcement;
    assert.equal(created.body.announcement.is_published, false);
    assert.deepEqual((await authed(user.token).get('/api/announcements')).body.announcements, []);

    assert.equal((await authed(admin.token).post('/api/admin/announcements').send({ title: '' , body: 'x' })).status, 400);

    await authed(admin.token).patch(`/api/admin/announcements/${id}`).send({ title: 'Exam week!' });
    const published = await authed(admin.token).post(`/api/admin/announcements/${id}/publish`);
    assert.equal(published.body.announcement.is_published, true);
    assert.ok(published.body.announcement.published_at > 0);

    const seen = (await authed(user.token).get('/api/announcements')).body.announcements;
    assert.deepEqual(seen.map((a) => a.title), ['Exam week!']);

    await authed(admin.token).post(`/api/admin/announcements/${id}/unpublish`);
    assert.equal((await authed(user.token).get('/api/announcements')).body.announcements.length, 0);

    assert.equal((await authed(admin.token).delete(`/api/admin/announcements/${id}`)).status, 200);
    assert.equal((await authed(admin.token).delete(`/api/admin/announcements/${id}`)).status, 404);
    assert.equal((await authed(user.token).post('/api/admin/announcements').send({ title: 'x', body: 'y' })).status, 403);
  });

  test('stats counts users and announcements', async () => {
    const admin = await makeAdmin();
    const res = await authed(admin.token).get('/api/admin/stats');
    assert.equal(res.status, 200);
    assert.ok(res.body.users >= 1);
    assert.ok(res.body.admins >= 1);
    assert.equal(typeof res.body.published, 'number');
  });
});
