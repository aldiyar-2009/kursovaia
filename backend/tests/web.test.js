import './setup.js';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { after, before, describe, test } from 'node:test';
import request from 'supertest';
import { createApp } from '../src/app.js';
import { db } from '../src/config/db.js';

let webDist;

before(() => {
  webDist = fs.mkdtempSync(path.join(os.tmpdir(), 'studyplan-web-'));
  fs.writeFileSync(path.join(webDist, 'index.html'), '<!doctype html><title>StudyPlan</title>');
});
after(async () => {
  fs.rmSync(webDist, { recursive: true, force: true });
  await db.destroy();
});

describe('web build hosting', () => {
  test('GET /join/:code serves the SPA index.html when the web build exists', async () => {
    const app = createApp({ webDist });
    const res = await request(app).get('/join/ABC123');
    assert.equal(res.status, 200);
    assert.match(res.text, /<title>StudyPlan<\/title>/);
    assert.equal((await request(app).get('/')).status, 200);
  });

  test('without a web build /join/:code is 404 and /api still works', async () => {
    const app = createApp({ webDist: null });
    assert.equal((await request(app).get('/join/ABC123')).status, 404);
    assert.equal((await request(app).get('/api/health')).status, 200);
  });
});
