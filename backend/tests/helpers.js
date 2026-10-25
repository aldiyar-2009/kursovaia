import './setup.js';
import crypto from 'node:crypto';
import request from 'supertest';
import { createApp } from '../src/app.js';
import { db } from '../src/config/db.js';

export const app = createApp();
export const uuid = () => crypto.randomUUID();

export async function resetDb() {
  await db.migrate.rollback(undefined, true);
  await db.migrate.latest();
}

let counter = 0;
export async function registerUser(name = 'User', extra = {}) {
  counter += 1;
  const res = await request(app)
    .post('/api/auth/register')
    .send({ email: `user${counter}_${Date.now()}@test.dev`, password: 'secret123', name, ...extra });
  if (res.status !== 201) throw new Error(`register failed: ${res.status} ${JSON.stringify(res.body)}`);
  return { token: res.body.token, user: res.body.user, group: res.body.group };
}

export const authed = (token) => ({
  get: (url) => request(app).get(url).set('Authorization', `Bearer ${token}`),
  post: (url) => request(app).post(url).set('Authorization', `Bearer ${token}`),
  patch: (url) => request(app).patch(url).set('Authorization', `Bearer ${token}`),
  del: (url) => request(app).delete(url).set('Authorization', `Bearer ${token}`),
  delete: (url) => request(app).delete(url).set('Authorization', `Bearer ${token}`),
});

export { db, request };
