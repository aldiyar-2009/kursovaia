import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { app, db, request, resetDb } from './helpers.js';
import {
  extractEventInfo,
  findDate,
  inferYear,
  parsePage,
  refreshEvents,
  saveEvents,
} from '../src/services/events.service.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const FIXTURE = fs.readFileSync(path.join(__dirname, 'fixtures', 'tme_dsvr_news.html'), 'utf8');
const POSTED = '2026-10-30T10:00:00+00:00';
const HOUR = 3_600_000;

describe('events from Telegram: parsing', () => {
  test('date formats: 01.11, «5 ноября», «1 қараша 2026», «Nov 4», «November 1, 2026»', () => {
    assert.deepEqual(findDate('📅 Дата: 01.11'), { d: 1, mo: 11, y: null });
    assert.deepEqual(findDate('🗓️ 5 ноября | 19:00'), { d: 5, mo: 11, y: null });
    assert.deepEqual(findDate('📅 Күні: 1 қараша 2026 жыл'), { d: 1, mo: 11, y: 2026 });
    assert.deepEqual(findDate('📍 Assembly Hall | 📅 Nov 4 | 🕓 16:00'), { d: 4, mo: 11, y: null });
    assert.deepEqual(findDate('📅 Date: November 1, 2026'), { d: 1, mo: 11, y: 2026 });
  });

  test('missing year: the one closest to the post date', () => {
    assert.equal(inferYear(5, 1, '2026-12-28T10:00:00Z'), 2027);
    assert.equal(inferYear(5, 11, '2026-10-30T10:00:00Z'), 2026);
  });

  test('12-hour time', () => {
    const e = extractEventInfo('SUNDAY OPEN\n📅 Date: October 18, 2026\n🕜 Time: 1:30 PM\n📍 Venue: Atameken Space', [], POSTED);
    assert.equal(e.starts_at, '2026-10-18T08:30:00.000Z'); // 13:30 in Astana (UTC+5)
    assert.equal(e.place, 'Atameken Space');
  });

  test('📆 line with date and time', () => {
    const e = extractEventInfo('Intellectual Games\n📆 4 November 2026, 18:30\n📍 Atameken Space', [], POSTED);
    assert.equal(e.starts_at, '2026-11-04T13:30:00.000Z');
    assert.equal(e.has_time, true);
  });

  test('a post without a date is not an event', () => {
    assert.equal(extractEventInfo('🎙 Новый выпуск подкаста TYF Media', ['https://youtu.be/x'], POSTED), null);
  });

  test('registration link and place', () => {
    const e = extractEventInfo(
      '🎬 Киноквиз!\n📅 Дата: 01.11\n⏰ Время: 11:00\n📍 Кабинет: С1.1.326\n👉 Ссылка на регистрацию',
      ['https://forms.gle/abc'],
      POSTED,
    );
    assert.equal(e.title, 'Киноквиз!');
    assert.equal(e.starts_at, '2026-11-01T06:00:00.000Z');
    assert.equal(e.has_time, true);
    assert.equal(e.place, 'С1.1.326');
    assert.equal(e.link, 'https://forms.gle/abc');
  });

  test('saved t.me/s/DSVR_News page is parsed', () => {
    const { events, before } = parsePage(FIXTURE, 'DSVR_News');
    assert.ok(events.length >= 5, `events: ${events.length}`);
    assert.ok(before);
    const quiz = events.find((e) => /Киноквиз/.test(e.title));
    assert.equal(quiz.place, 'С1.1.326');
    assert.match(quiz.post_url, /^https:\/\/t\.me\/DSVR_News\/\d+$/);
  });
});

describe('GET /api/events', () => {
  before(resetDb);
  after(() => db.destroy());

  const base = { source: 'test', text: 'text', place: null, link: null, image_url: null, post_url: null };
  const iso = (ms) => new Date(ms).toISOString();

  test('refreshEvents stores parsed posts with epoch-ms times (idempotent)', async () => {
    const fetchImpl = async () => ({ ok: true, status: 200, text: async () => FIXTURE });
    const n = await refreshEvents({ pages: 1, channels: ['DSVR_News'], fetchImpl });
    assert.ok(n >= 5);
    await refreshEvents({ pages: 1, channels: ['DSVR_News'], fetchImpl });
    const rows = await db('events').where({ source: 'DSVR_News' });
    assert.equal(rows.length, n);
    assert.ok(rows.every((r) => Number.isInteger(Number(r.starts_at)) && Number(r.posted_at) > 0));
  });

  test('upcoming / past split with the "ended" rule', async () => {
    const now = Date.now();
    await saveEvents([
      { ...base, external_id: 'future', title: 'Future', starts_at: iso(now + 48 * HOUR), has_time: true, posted_at: iso(now) },
      // Started an hour ago with a time: still running (ends 2 h after start).
      { ...base, external_id: 'running', title: 'Running', starts_at: iso(now - HOUR), has_time: true, posted_at: iso(now) },
      { ...base, external_id: 'ended', title: 'Ended', starts_at: iso(now - 3 * HOUR), has_time: true, posted_at: iso(now) },
      // All-day event that started 12 h ago: still today.
      { ...base, external_id: 'allday', title: 'All day', starts_at: iso(now - 12 * HOUR), has_time: false, posted_at: iso(now) },
      { ...base, external_id: 'old', title: 'Old', starts_at: iso(now - 30 * HOUR), has_time: false, posted_at: iso(now) },
    ]);

    const up = await request(app).get('/api/events').query({ scope: 'upcoming', limit: 200 });
    assert.equal(up.status, 200);
    const upTitles = up.body.events.filter((e) => ['Future', 'Running', 'All day', 'Ended', 'Old'].includes(e.title)).map((e) => e.title);
    assert.deepEqual(upTitles, ['All day', 'Running', 'Future']);
    const ev = up.body.events.find((e) => e.title === 'Future');
    assert.deepEqual(Object.keys(ev).sort(), ['has_time', 'id', 'image_url', 'link', 'place', 'post_url', 'starts_at', 'text', 'title']);
    assert.equal(typeof ev.starts_at, 'number');
    assert.equal(ev.has_time, true);

    const past = await request(app).get('/api/events').query({ scope: 'past', limit: 200 });
    const pastTitles = past.body.events.map((e) => e.title);
    assert.ok(pastTitles.indexOf('Ended') < pastTitles.indexOf('Old'));
    assert.ok(!pastTitles.includes('Future'));

    const limited = await request(app).get('/api/events').query({ scope: 'past', limit: 1 });
    assert.equal(limited.body.events.length, 1);
  });
});
