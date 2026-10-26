import './setup.js';
import assert from 'node:assert/strict';
import { test } from 'node:test';
import request from 'supertest';
import { createApp } from '../src/app.js';
import { androidIntentUrl } from '../src/utils/open-app.js';

const ANDROID_UA = 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 Chrome/130 Mobile Safari/537.36';

test('androidIntentUrl opens the app with the server origin and falls back to the web app', () => {
  const url = androidIntentUrl('http://192.168.0.10:3000');
  assert.equal(
    url,
    'intent://connect?server=http%3A%2F%2F192.168.0.10%3A3000'
      + '#Intent;scheme=studyplan;package=com.studyplan.studyplan;'
      + 'S.browser_fallback_url=http%3A%2F%2F192.168.0.10%3A3000%2F;end',
  );
});

test('GET /open on Android serves the open-app page for the requested host', async () => {
  const res = await request(createApp({ webDist: null }))
    .get('/open')
    .set('Host', '192.168.0.10:3000')
    .set('User-Agent', ANDROID_UA);
  assert.equal(res.status, 200);
  assert.match(res.headers['content-type'], /html/);
  assert.ok(res.text.includes('intent://connect?server=http%3A%2F%2F192.168.0.10%3A3000'));
});

test('GET /open elsewhere redirects to the web app', async () => {
  const res = await request(createApp({ webDist: null }))
    .get('/open')
    .set('User-Agent', 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X)');
  assert.equal(res.status, 302);
  assert.equal(res.headers.location, '/');
});

test('GET /open ignores a malformed Host header', async () => {
  const res = await request(createApp({ webDist: null }))
    .get('/open')
    .set('Host', 'evil"><script>')
    .set('User-Agent', ANDROID_UA);
  assert.equal(res.status, 302);
});
