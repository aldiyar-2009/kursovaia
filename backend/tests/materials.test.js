import './setup.js';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { after, before, describe, it } from 'node:test';
import { env } from '../src/config/env.js';
import { createMaterial } from '../src/services/materials.service.js';
import { app, authed, db, request, resetDb, uuid } from './helpers.js';

const uploadedFiles = () => new Set(fs.readdirSync(env.uploadDir));

/** Multipart upload with a small PDF attached; `fields` are sent as form fields. */
function uploadWithFile(token, fields, fileName = 'notes.pdf') {
  const req = authed(token).post('/api/materials/upload');
  for (const [k, v] of Object.entries(fields)) req.field(k, v);
  return req.attach('file', Buffer.from('%PDF-1.4 demo'), fileName);
}

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

  it('allows student to upload study material', async () => {
    const res = await uploadWithFile(studentToken, {
      title: 'Конспект по дискретной математике: Рекуррентные соотношения',
      subject_code: 'discrete',
      subject_title: 'Discrete Mathematics',
      category: 'lecture',
    }, 'discrete_math_notes.pdf');

    assert.equal(res.status, 201);
    assert.equal(res.body.material.title, 'Конспект по дискретной математике: Рекуррентные соотношения');
    assert.equal(res.body.material.uploader_name, 'Студент');
    assert.equal(res.body.material.file_name, 'discrete_math_notes.pdf');
    assert.equal(res.body.material.file_type, 'pdf');

    const list = await authed(studentToken).get('/api/materials');
    assert.ok(list.body.materials.some((m) => m.id === res.body.material.id));
  });

  it('upload without a file is rejected with 400 (no virtual materials)', async () => {
    const before = await db('course_materials').count({ n: '*' }).first();
    const res = await authed(studentToken).post('/api/materials/upload').send({
      title: 'Без файла', file_name: 'ghost.pdf', file_size: 1540000,
    });
    assert.equal(res.status, 400);
    const afterCount = await db('course_materials').count({ n: '*' }).first();
    assert.equal(Number(afterCount.n), Number(before.n));
  });

  it('upload without subject stores and returns null subject fields', async () => {
    const res = await uploadWithFile(studentToken, { title: 'Без предмета' });
    assert.equal(res.status, 201);
    assert.equal(res.body.material.subject_code, null);
    assert.equal(res.body.material.subject_title, null);

    const row = await db('course_materials').where({ id: res.body.material.id }).first();
    assert.equal(row.subject_code, null);
    assert.equal(row.subject_title, null);
  });

  it('empty strings and legacy placeholders none / - are stored as null', async () => {
    for (const [code, title] of [['none', '-'], ['', ''], ['  ', ' ']]) {
      // eslint-disable-next-line no-await-in-loop
      const res = await uploadWithFile(studentToken, { title: 'Плейсхолдер', subject_code: code, subject_title: title });
      assert.equal(res.status, 201);
      assert.equal(res.body.material.subject_code, null);
      assert.equal(res.body.material.subject_title, null);
    }
  });

  it('trims fields and truncates them to the column sizes', async () => {
    const longTitle = 'Т'.repeat(300);
    const longSubject = 'Очень длинное название предмета '.repeat(10); // > 120 chars
    const res = await uploadWithFile(studentToken, {
      title: `  ${longTitle}  `,
      subject_code: longSubject,
      subject_title: `  ${longSubject}  `,
      category: `  ${'c'.repeat(50)}  `,
      description: '  Описание  ',
    }, `${'н'.repeat(300)}.pdf`);
    assert.equal(res.status, 201);
    const m = res.body.material;
    assert.equal(m.title, 'Т'.repeat(200));
    assert.ok(m.subject_code.length <= 32);
    assert.equal(m.subject_code, longSubject.trim().slice(0, 32).trim());
    assert.ok(m.subject_title.length <= 120);
    assert.equal(m.subject_title, longSubject.trim().slice(0, 120).trim());
    assert.equal(m.category.length, 32);
    assert.equal(m.description, 'Описание');
    assert.ok(m.file_name.length <= 255);
    assert.ok(m.file_name.endsWith('.pdf'), 'extension survives truncation');
    assert.ok(m.file_type.length <= 16);
  });

  it('subject_code falls back to the (truncated) subject title when absent', async () => {
    const res = await uploadWithFile(studentToken, { title: 'Код из названия', subject_title: 'Introduction to Programming and Algorithms' });
    assert.equal(res.status, 201);
    assert.equal(res.body.material.subject_code, 'Introduction to Programming and');
  });

  it('validation error after the file was saved removes the file from disk', async () => {
    const filesBefore = uploadedFiles();
    const res = await uploadWithFile(studentToken, { title: '   ' });
    assert.equal(res.status, 400);
    assert.deepEqual(uploadedFiles(), filesBefore, 'no orphaned upload');
  });

  it('user without a group: 400 and the uploaded file is removed', async () => {
    const reg = await request(app).post('/api/auth/register').send({ email: 'nogroup@test.dev', password: 'secret123', name: 'Без группы' });
    const filesBefore = uploadedFiles();
    const res = await uploadWithFile(reg.body.token, { title: 'x' });
    assert.equal(res.status, 400);
    assert.deepEqual(uploadedFiles(), filesBefore);
  });

  it('DB error after the file was saved removes the file from disk', async () => {
    const tmpName = `${uuid()}.pdf`;
    const tmpPath = path.join(env.uploadDir, tmpName);
    fs.writeFileSync(tmpPath, '%PDF-1.4');
    const file = { originalname: 'x.pdf', filename: tmpName, path: tmpPath, size: 8 };
    // group_id does not exist -> FK violation on insert.
    const user = { id: uuid(), name: 'Ghost', group_id: uuid() };
    await assert.rejects(() => createMaterial(user, file, { title: 'Ошибка БД' }));
    assert.equal(fs.existsSync(tmpPath), false);
  });

  it('deleting a material removes its file from disk', async () => {
    const up = await uploadWithFile(studentToken, { title: 'Черновик для удаления', subject_code: 'py' });
    assert.equal(up.status, 201);
    const filePath = path.join(env.uploadDir, up.body.material.file_path);
    assert.ok(fs.existsSync(filePath));

    const delRes = await authed(studentToken).delete(`/api/materials/${up.body.material.id}`);
    assert.equal(delRes.status, 200);
    assert.equal(delRes.body.success, true);
    assert.equal(fs.existsSync(filePath), false);
  });

  it('only uploader can delete material', async () => {
    const create = await uploadWithFile(studentToken, { title: 'Конспект студента', subject_code: 'py' });
    assert.equal(create.status, 201);
    const matId = create.body.material.id;

    // The seeded "headman" account has role=headman in the DB; roles no longer grant anything.
    const other = await authed(headmanToken).delete(`/api/materials/${matId}`);
    assert.equal(other.status, 403);
    assert.ok(fs.existsSync(path.join(env.uploadDir, create.body.material.file_path)), 'file kept on forbidden delete');

    const own = await authed(studentToken).delete(`/api/materials/${matId}`);
    assert.equal(own.status, 200);
  });

  it('deleting a seeded material without a file on disk still succeeds', async () => {
    const student = await db('users').where({ email: 'student@studyplan.dev' }).first();
    const own = await db('course_materials').where({ uploader_id: student.id });
    const seeded = own.find((m) => !fs.existsSync(path.join(env.uploadDir, m.file_path)));
    assert.ok(seeded, 'seed has a student material without a file');
    const res = await authed(studentToken).delete(`/api/materials/${seeded.id}`);
    assert.equal(res.status, 200);
  });

  it('any member can upload', async () => {
    const up = await uploadWithFile(headmanToken, { title: 'От участника' });
    assert.equal(up.status, 201);
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
