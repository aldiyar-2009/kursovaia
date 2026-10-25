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
});
