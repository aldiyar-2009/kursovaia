import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import { createApp } from '../src/app.js';

describe('AITU LMS integration', () => {
  const app = createApp();

  it('rejects login without credentials', async () => {
    const res = await request(app)
      .post('/api/lms/login')
      .send({});
    assert.equal(res.status, 400);
    assert.equal(res.body.success, false);
    assert.match(res.body.error, /логин и пароль/i);
  });

  it('handles invalid login credentials from real LMS safely', async () => {
    const res = await request(app)
      .post('/api/lms/login')
      .send({
        username: 'nonexistent_test_student_12345',
        password: 'wrong_password_999',
      });
    assert.equal(res.status, 401);
    assert.equal(res.body.success, false);
    assert.match(res.body.error, /LMS Astana IT University/i);
  });
});
