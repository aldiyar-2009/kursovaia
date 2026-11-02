import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { app, db, request, resetDb } from './helpers.js';
import { importAll, importIfEmpty, normGroup, parseAll, parseTimeRange } from '../src/services/timetable.service.js';

describe('college timetable import from Excel', () => {
  let rows;
  before(async () => {
    rows = await parseAll();
  });

  test('parseTimeRange understands both halves of a pair and a single range', () => {
    assert.deepEqual(parseTimeRange('8.00-8.45 8.50-9.35 '), ['08:00', '09:35']);
    assert.deepEqual(parseTimeRange('13.30-15.00'), ['13:30', '15:00']);
    assert.equal(parseTimeRange(''), null);
  });

  test('normGroup drops «Группа» and spaces', () => {
    assert.equal(normGroup('Группа  ПО2406'), 'ПО2406');
    assert.equal(normGroup('по 2501'), 'ПО2501');
  });

  test('real files: ПО2501, Monday, pair 1', () => {
    const first = rows.find((r) => r.group_name === 'ПО2501' && r.day_of_week === 1 && r.pair_no === 1);
    assert.equal(first.subject, 'Администрирование баз данных');
    assert.equal(first.start_time, '08:00');
    assert.equal(first.end_time, '09:35');
    assert.equal(first.room, 'С1.3.240');
    assert.equal(first.valid_from, '2026-09-01');
  });

  test('empty time comes from the shift bells (pair IV in the morning, pair 0 in the afternoon)', () => {
    const fourth = rows.find((r) => r.group_name === 'ПО2501' && r.day_of_week === 1 && r.pair_no === 4);
    assert.deepEqual([fourth.start_time, fourth.end_time], ['13:30', '15:00']);
    const zero = rows.find((r) => r.group_name === 'ПО2506' && r.pair_no === 0);
    assert.deepEqual([zero.start_time, zero.end_time], ['11:40', '13:15']);
  });

  test('3rd year has two periods: theory and production practice', () => {
    const own = rows.filter((r) => r.group_name === 'ПО2406');
    const periods = [...new Set(own.map((r) => `${r.valid_from}..${r.valid_to}`))].sort();
    assert.deepEqual(periods, ['2026-09-01..2026-10-12', '2026-10-13..2026-11-09']);
  });
});

describe('GET /api/timetable', () => {
  before(async () => {
    await resetDb();
    await importIfEmpty(db);
  });
  after(() => db.destroy());

  test('importIfEmpty does nothing when lessons exist; importAll replaces them', async () => {
    assert.equal(await importIfEmpty(db), 0);
    const n = await importAll(db);
    const { c } = await db('timetable_lessons').count({ c: '*' }).first();
    assert.equal(Number(c), n);
  });

  test('lessons of a group (public, group normalised)', async () => {
    const res = await request(app).get('/api/timetable').query({ group: 'по 2501' });
    assert.equal(res.status, 200);
    assert.equal(res.body.group, 'ПО2501');
    assert.ok(res.body.lessons.length > 0);
    const [first] = res.body.lessons;
    assert.deepEqual(Object.keys(first).sort(), [
      'day_of_week', 'end_time', 'pair_no', 'room', 'start_time', 'subject', 'teacher', 'valid_from', 'valid_to',
    ]);
    assert.match(first.start_time, /^\d{2}:\d{2}$/);
    assert.match(first.valid_from, /^\d{4}-\d{2}-\d{2}$/);
  });

  test('unknown group -> empty list; missing group -> 400', async () => {
    const unknown = await request(app).get('/api/timetable').query({ group: 'XX0000' });
    assert.equal(unknown.status, 200);
    assert.deepEqual(unknown.body.lessons, []);
    assert.equal((await request(app).get('/api/timetable')).status, 400);
  });

  test('GET /api/timetable/groups lists the imported groups', async () => {
    const res = await request(app).get('/api/timetable/groups');
    assert.equal(res.status, 200);
    assert.ok(res.body.groups.includes('ПО2501'));
    assert.ok(res.body.groups.includes('ПО2406'));
    assert.deepEqual(res.body.groups, [...res.body.groups].sort());
  });
});
