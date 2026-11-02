import fs from 'node:fs';
import path from 'node:path';
import ExcelJS from 'exceljs';
import { db } from '../config/db.js';
import { ROOT_DIR } from '../config/env.js';
import { badRequest } from '../utils/http-error.js';

/**
 * College timetable imported from Excel (data/timetables, see manifest.json).
 *
 * Sheet layout: a row "Группа ПО2501" above the header "Дни недели | Пара | Время |
 * Дисциплина | Преподаватель | аудитория". Every group has its own block of columns
 * (usually 6, sometimes 4 — without time and room). The weekday is a merged cell.
 *
 * Shifts: morning — pairs I–IV, afternoon — pairs 0, I–III. When a cell has no time,
 * it is taken from the bell schedule (BELLS).
 */

export const TIMETABLE_DIR = path.join(ROOT_DIR, 'data', 'timetables');

// Bells (from the cells with explicit times in the college timetable).
export const BELLS = {
  morning: { I: ['08:00', '09:35'], II: ['09:45', '11:20'], III: ['11:40', '13:15'], IV: ['13:30', '15:00'] },
  afternoon: { 0: ['11:40', '13:15'], I: ['13:30', '15:00'], II: ['15:20', '16:50'], III: ['17:00', '18:30'] },
};
const PAIR_NO = { 0: 0, I: 1, II: 2, III: 3, IV: 4, V: 5 };

const DAYS = [
  [/понедельник|дүйсенбі/i, 1],
  [/вторник|сейсенбі/i, 2],
  [/среда|сәрсенбі/i, 3],
  [/четверг|бейсенбі/i, 4],
  [/пятница|жұма/i, 5],
  [/суббота|сенбі/i, 6],
];

const text = (cell) => String(cell?.text ?? '').replace(/\s+/g, ' ').trim();

/** "Группа  ПО2406" / "по 2406" -> "ПО2406" */
export const normGroup = (s) => String(s || '').replace(/^Группа/i, '').replace(/\s+/g, '').toUpperCase();

const pad = (t) => {
  const [h, m] = t.split(/[.:]/);
  return `${h.padStart(2, '0')}:${(m || '00').padEnd(2, '0')}`;
};

/** "8.00-8.45 8.50-9.35" -> ["08:00","09:35"]; "13.30-15.00" -> ["13:30","15:00"] */
export function parseTimeRange(s) {
  const times = String(s || '').match(/\d{1,2}[.:]\d{2}/g);
  if (!times || times.length < 2) return null;
  return [pad(times[0]), pad(times[times.length - 1])];
}

function dayOfWeek(s) {
  for (const [re, n] of DAYS) if (re.test(s)) return n;
  return null;
}

/** Parses one sheet: [{group_name, day_of_week, pair_no, start_time, end_time, subject, teacher, room}]. */
export function parseWorksheet(ws) {
  // 1. Header row (contains "Дни недели").
  let headerRow = null;
  for (let r = 1; r <= Math.min(ws.rowCount, 10) && !headerRow; r += 1) {
    ws.getRow(r).eachCell((c) => {
      if (/^Дни недели/i.test(text(c))) headerRow = r;
    });
  }
  if (!headerRow) return [];

  // 2. Column blocks: each one starts with "Дни недели".
  const header = ws.getRow(headerRow);
  const starts = [];
  for (let c = 1; c <= ws.columnCount; c += 1) if (/^Дни недели/i.test(text(header.getCell(c)))) starts.push(c);

  const lessons = [];
  starts.forEach((start, i) => {
    const end = (starts[i + 1] || ws.columnCount + 1) - 1;
    const group = normGroup(text(ws.getRow(headerRow - 1).getCell(start)));
    if (!group) return;

    const cols = {};
    for (let c = start; c <= end; c += 1) {
      const h = text(header.getCell(c)).toLowerCase();
      if (h.startsWith('дни')) cols.day = c;
      else if (h.startsWith('пара')) cols.pair = c;
      else if (h.startsWith('время')) cols.time = c;
      else if (h.startsWith('название')) cols.subject = c;
      else if (h.startsWith('преподав')) cols.teacher = c;
      else if (h.startsWith('аудитор')) cols.room = c;
    }

    const rows = [];
    for (let r = headerRow + 1; r <= ws.rowCount; r += 1) {
      const row = ws.getRow(r);
      const day = dayOfWeek(text(row.getCell(cols.day)));
      if (!day) continue;
      rows.push({ row, day, pair: text(row.getCell(cols.pair)).toUpperCase() });
    }
    // Afternoon shift — when the block has a "zero" pair.
    const shift = rows.some((x) => x.pair === '0') ? 'afternoon' : 'morning';

    for (const { row, day, pair } of rows) {
      const subject = cols.subject ? text(row.getCell(cols.subject)) : '';
      if (!subject || !(pair in PAIR_NO)) continue;
      const range = (cols.time && parseTimeRange(text(row.getCell(cols.time)))) || BELLS[shift][pair];
      if (!range) continue;
      lessons.push({
        group_name: group,
        day_of_week: day,
        pair_no: PAIR_NO[pair],
        start_time: range[0],
        end_time: range[1],
        subject: subject.slice(0, 150),
        teacher: (cols.teacher && text(row.getCell(cols.teacher)).slice(0, 150)) || null,
        room: (cols.room && text(row.getCell(cols.room)).slice(0, 50)) || null,
      });
    }
  });
  return lessons;
}

export async function parseFile(file, sheetName) {
  const wb = new ExcelJS.Workbook();
  await wb.xlsx.readFile(file);
  const ws = wb.getWorksheet(sheetName);
  if (!ws) throw new Error(`Sheet "${sheetName}" not found in ${path.basename(file)}`);
  return parseWorksheet(ws);
}

/** Reads manifest.json and returns all lessons with their validity periods. */
export async function parseAll(dir = TIMETABLE_DIR) {
  const manifest = JSON.parse(fs.readFileSync(path.join(dir, 'manifest.json'), 'utf8'));
  const all = [];
  for (const src of manifest.sources) {
    // eslint-disable-next-line no-await-in-loop
    const lessons = await parseFile(path.join(dir, src.file), src.sheet);
    for (const l of lessons) all.push({ ...l, valid_from: src.valid_from, valid_to: src.valid_to, source: src.label });
  }
  return all;
}

/** Replaces the whole timetable_lessons table. Returns the number of lessons. */
export async function importAll(conn = db, dir = TIMETABLE_DIR) {
  const rows = await parseAll(dir);
  await conn.transaction(async (trx) => {
    await trx('timetable_lessons').del();
    // SQLite allows at most 999 bound variables per statement: 11 columns x 50 rows.
    for (let i = 0; i < rows.length; i += 50) {
      // eslint-disable-next-line no-await-in-loop
      await trx('timetable_lessons').insert(rows.slice(i, i + 50));
    }
  });
  return rows.length;
}

/** Imports the timetable when the table is empty (server start). */
export async function importIfEmpty(conn = db) {
  const row = await conn('timetable_lessons').count({ n: '*' }).first();
  if (Number(row?.n ?? 0) > 0) return 0;
  return importAll(conn);
}

/** GET /timetable?group= */
export async function getTimetable(groupParam) {
  const group = normGroup(typeof groupParam === 'string' ? groupParam : '');
  if (!group) throw badRequest('group is required');
  const rows = await db('timetable_lessons')
    .where({ group_name: group })
    .orderBy([{ column: 'valid_from' }, { column: 'day_of_week' }, { column: 'pair_no' }]);
  return {
    group,
    lessons: rows.map((r) => ({
      day_of_week: r.day_of_week,
      pair_no: r.pair_no,
      start_time: r.start_time,
      end_time: r.end_time,
      subject: r.subject,
      teacher: r.teacher,
      room: r.room,
      valid_from: r.valid_from,
      valid_to: r.valid_to,
    })),
  };
}

/** GET /timetable/groups */
export async function listGroups() {
  const rows = await db('timetable_lessons').distinct('group_name').orderBy('group_name');
  return { groups: rows.map((r) => r.group_name) };
}
