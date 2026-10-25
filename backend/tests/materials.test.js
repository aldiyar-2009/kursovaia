import './setup.js';
import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';
import { app, authed, db, request, resetDb } from './helpers.js';

describe('University course materials API', () => {
  let headmanToken;
  let studentToken;

  before(async () => {
    await resetDb();
    await db.seed.run();

    const hmLogin = await request(app).post('/api/auth/login').send({
      email: 'headman@studyplan.dev',
      password: 'password123',
    });
    headmanToken = hmLogin.body.token;

    const stLogin = await request(app).post('/api/auth/login').send({
      email: 'student@studyplan.dev',
      password: 'password123',
    });
    studentToken = stLogin.body.token;
  });

  after(() => db.destroy());

  it('lists seeded university materials', async () => {
    const res = await authed(studentToken).get('/api/materials');
    assert.equal(res.status, 200);
    assert.ok(Array.isArray(res.body.materials));
    assert.ok(res.body.materials.length >= 7);
    assert.ok(res.body.materials.some((m) => m.subject_code === 'py'));
    assert.ok(res.body.materials.some((m) => m.subject_code === 'math'));
  });

  it('filters materials by subject_code', async () => {
    const res = await authed(studentToken).get('/api/materials?subject=py');
    assert.equal(res.status, 200);
    assert.ok(res.body.materials.every((m) => m.subject_code === 'py'));
  });

  it('allows student to upload/create study material', async () => {
    const res = await authed(studentToken)
      .post('/api/materials/upload')
      .send({
        title: 'Конспект по дискретной математике: Рекуррентные соотношения',
        subject_code: 'discrete',
        subject_title: 'Discrete Mathematics',
        category: 'lecture',
        file_name: 'discrete_math_notes.pdf',
        file_size: 1540000,
      });

    assert.equal(res.status, 201);
    assert.equal(res.body.material.title, 'Конспект по дискретной математике: Рекуррентные соотношения');
    assert.equal(res.body.material.uploader_name, 'Студент');

    // verify it shows in list
    const list = await authed(studentToken).get('/api/materials');
    assert.ok(list.body.materials.some((m) => m.id === res.body.material.id));
  });

  it('upload without subject stores and returns null subject fields', async () => {
    const res = await authed(studentToken).post('/api/materials/upload').send({ title: 'Без предмета' });
    assert.equal(res.status, 201);
    assert.equal(res.body.material.subject_code, null);
    assert.equal(res.body.material.subject_title, null);

    const row = await db('course_materials').where({ id: res.body.material.id }).first();
    assert.equal(row.subject_code, null);
    assert.equal(row.subject_title, null);

    const list = await authed(studentToken).get('/api/materials');
    const listed = list.body.materials.find((m) => m.id === res.body.material.id);
    assert.equal(listed.subject_code, null);
    assert.equal(listed.subject_title, null);
  });

  it('empty strings and legacy placeholders none / - are stored as null', async () => {
    for (const [code, title] of [['none', '-'], ['', ''], ['  ', ' ']]) {
      // eslint-disable-next-line no-await-in-loop
      const res = await authed(studentToken)
        .post('/api/materials/upload')
        .send({ title: 'Плейсхолдер', subject_code: code, subject_title: title });
      assert.equal(res.status, 201);
      assert.equal(res.body.material.subject_code, null);
      assert.equal(res.body.material.subject_title, null);
      // eslint-disable-next-line no-await-in-loop
      const row = await db('course_materials').where({ id: res.body.material.id }).first();
      assert.equal(row.subject_code, null);
      assert.equal(row.subject_title, null);
    }
  });

  it('virtual upload without file_size does not invent a size', async () => {
    const res = await authed(studentToken).post('/api/materials/upload').send({ title: 'Без размера' });
    assert.equal(res.status, 201);
    assert.equal(res.body.material.file_size, 0);
  });

  it('student can delete own material', async () => {
    const create = await authed(studentToken)
      .post('/api/materials/upload')
      .send({
        title: 'Черновик для удаления',
        subject_code: 'py',
        subject_title: 'Introduction to Programming',
      });

    const matId = create.body.material.id;
    const delRes = await authed(studentToken).delete(`/api/materials/${matId}`);
    assert.equal(delRes.status, 200);
    assert.equal(delRes.body.success, true);
  });

  it('only uploader can delete material', async () => {
    const create = await authed(studentToken)
      .post('/api/materials/upload')
      .send({ title: 'Конспект студента', subject_code: 'py', subject_title: 'Introduction to Programming' });
    assert.equal(create.status, 201);
    const matId = create.body.material.id;

    // The seeded "headman" account has role=headman in the DB; roles no longer grant anything.
    const other = await authed(headmanToken).delete(`/api/materials/${matId}`);
    assert.equal(other.status, 403);

    const own = await authed(studentToken).delete(`/api/materials/${matId}`);
    assert.equal(own.status, 200);
  });

  it('any member can upload; without a group upload is rejected', async () => {
    const up = await authed(headmanToken).post('/api/materials/upload').send({ title: 'От участника' });
    assert.equal(up.status, 201);

    const reg = await request(app).post('/api/auth/register').send({ email: 'nogroup@test.dev', password: 'secret123', name: 'Без группы' });
    const res = await authed(reg.body.token).post('/api/materials/upload').send({ title: 'x' });
    assert.equal(res.status, 400);
  });

  it('real file upload + authorized download via /api/files/:name', async () => {
    const up = await authed(studentToken)
      .post('/api/materials/upload')
      .field('title', 'Методичка')
      .attach('file', Buffer.from('%PDF-1.4 demo'), 'методичка.pdf');
    assert.equal(up.status, 201);
    assert.equal(up.body.material.file_name, 'методичка.pdf');
    const url = `/api/files/${up.body.material.file_path}`;
    const down = await authed(studentToken).get(url);
    assert.equal(down.status, 200);
    assert.equal((await request(app).get(url)).status, 401);
    assert.equal((await authed(studentToken).get('/api/files/..%2F..%2F.env')).status, 404);
  });

  it('material download: group member 200 as attachment, other group 404, no group 404', async () => {
    const up = await authed(studentToken)
      .post('/api/materials/upload')
      .field('title', 'Только для группы')
      .attach('file', Buffer.from('%PDF-1.4 secret'), 'secret.pdf');
    assert.equal(up.status, 201);
    const url = `/api/files/${up.body.material.file_path}`;

    const member = await authed(headmanToken).get(url);
    assert.equal(member.status, 200);
    assert.match(member.headers['content-disposition'], /^attachment/);
    assert.match(member.headers['content-disposition'], /secret\.pdf/);
    assert.equal(member.headers['x-content-type-options'], 'nosniff');

    const otherReg = await request(app).post('/api/auth/register').send({ email: 'othergroup@test.dev', password: 'secret123', name: 'Чужой' });
    const otherGroup = await authed(otherReg.body.token).post('/api/groups').send({ title: 'OTHER-1' });
    assert.equal((await authed(otherGroup.body.token).get(url)).status, 404);

    const lonerReg = await request(app).post('/api/auth/register').send({ email: 'loner-dl@test.dev', password: 'secret123', name: 'Одиночка' });
    assert.equal((await authed(lonerReg.body.token).get(url)).status, 404);
  });
});
