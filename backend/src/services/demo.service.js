import fs from 'node:fs/promises';
import path from 'node:path';
import { db } from '../config/db.js';
import { env } from '../config/env.js';
import { SYNC_ORDER } from '../db/schema.js';
import { badRequest, forbidden } from '../utils/http-error.js';
import { generateInviteCode, newId, toBool } from '../utils/validators.js';
import { buildSession } from './auth.service.js';
import { buildStats } from './smartnation/sync.js';

/**
 * Demo accounts: a real user (`is_demo`, no email/password) pre-filled with a
 * timetable, tasks, grades, LMS deadlines and group materials, so the app can be
 * tried without registering or connecting the LMS. Everything the visitor adds is
 * stored and synced like for any account. Only inserts rows for the new user, so
 * it is safe on the production database (unlike the seed, which wipes tables).
 */

const HOUR = 3_600_000;
const DAY = 24 * HOUR;

const SUBJECTS = [
  { key: 'mob', title: 'Mobile Application Development', teacher: 'Tileules D.N.', color: '#10B981', lms: 900101 },
  { key: 'db', title: 'Databases', teacher: 'Akhmadieva A.K.', color: '#6366F1', lms: 900102 },
  { key: 'web', title: 'Web Technologies', teacher: 'Tanzharbaeva M.A.', color: '#06B6D4', lms: 900103 },
  { key: 'eng', title: 'Professional English', teacher: 'Language Centre', color: '#EC4899', lms: 900104 },
  { key: 'hist', title: 'History of Kazakhstan', teacher: 'Humanities Department', color: '#F59E0B', lms: 900105 },
];

// [subjectKey, day, start, end, room, type, isEvenWeek (null = every week), topic]
const TIMETABLE = [
  ['mob', 1, '08:30', '09:50', 'C1.2.204', 'lecture', null, 'Flutter: widgets and layouts'],
  ['db', 1, '10:00', '11:20', 'C1.2.214', 'practice', null, 'SQL joins and indexes'],
  ['web', 2, '10:00', '11:20', 'C1.3.402', 'lecture', null, 'REST API design'],
  ['eng', 2, '11:30', '12:50', 'C1.2.118', 'practice', null, 'Technical presentations'],
  ['mob', 3, '08:30', '09:50', 'C1.1.105', 'lab', null, 'State management with BLoC'],
  ['hist', 3, '13:00', '14:20', 'C1.1.220', 'lecture', false, 'Kazakh Khanate'],
  ['db', 4, '10:00', '11:20', 'C1.3.307', 'lab', null, 'Transactions and isolation'],
  ['web', 4, '11:30', '12:50', 'C1.3.410', 'lab', true, 'Express.js middleware'],
  ['eng', 5, '10:00', '11:20', 'C1.2.118', 'practice', null, 'Academic writing'],
  ['mob', 5, '11:30', '12:50', 'C1.1.105', 'lab', null, 'Offline-first sync'],
];

// [subjectKey, midterm, endterm, final (null = exam not taken yet)]
const GRADES = [
  ['mob', 92, 88, null],
  ['db', 78, 84, null],
  ['web', 95, 91, null],
  ['eng', 70, 64, null],
  ['hist', 85, 90, 88],
];

const MATERIALS = [
  {
    subject: 'mob',
    title: 'Lab 4: offline-first synchronisation',
    category: 'lab',
    file: 'lab4_offline_sync.txt',
    content: 'Lab 4. Offline-first synchronisation\n\n1. Store every change locally with a pending status.\n2. Push pending rows to POST /api/sync.\n3. Resolve conflicts with Last-Write-Wins on updated_at.\n4. Pull rows changed since the last sync.\n',
  },
  {
    subject: 'db',
    title: 'SQL cheat sheet: joins and indexes',
    category: 'lecture',
    file: 'sql_cheat_sheet.txt',
    content: 'SQL cheat sheet\n\nINNER JOIN - rows present in both tables.\nLEFT JOIN - all rows of the left table.\nCREATE INDEX idx ON table(column);\nEXPLAIN ANALYZE SELECT ...;\n',
  },
  {
    subject: 'web',
    title: 'Syllabus: Web Technologies',
    category: 'syllabus',
    file: 'web_syllabus.txt',
    content: 'Web Technologies - syllabus\n\nWeeks 1-5: HTML, CSS, JavaScript.\nWeeks 6-10: Node.js, Express, REST.\nWeeks 11-15: authentication, deployment.\nAssessment: midterm 30%, endterm 30%, final exam 40%.\n',
  },
];

async function uniqueInviteCode(trx) {
  for (let i = 0; i < 10; i += 1) {
    const code = generateInviteCode();
    // eslint-disable-next-line no-await-in-loop
    if (!(await trx('groups').where({ invite_code: code }).first('id'))) return code;
  }
  throw new Error('Could not generate a unique invite code');
}

const sync = (now) => ({ is_deleted: false, updated_at: now, server_updated_at: now });

/** Inserts the demo content for `userId` (member of `groupId`) inside `trx`. Returns stored file names. */
async function fillDemoData(trx, userId, groupId, userName) {
  const now = Date.now();
  const subjectIds = {};
  await trx('subjects').insert(SUBJECTS.map((s) => {
    subjectIds[s.key] = newId();
    return { id: subjectIds[s.key], user_id: userId, title: s.title, teacher_name: s.teacher, color_hex: s.color, ...sync(now) };
  }));

  await trx('lessons').insert(TIMETABLE.map(([key, day, start, end, room, type, even, topic]) => ({
    id: newId(),
    subject_id: subjectIds[key],
    user_id: userId,
    day_of_week: day,
    start_time: start,
    end_time: end,
    classroom: room,
    lesson_type: type,
    topic,
    is_even_week: even,
    specific_date: null,
    valid_from: null,
    valid_to: null,
    is_cancelled: false,
    ...sync(now),
  })));

  const title = (key) => SUBJECTS.find((s) => s.key === key).title;
  const task = (key, name, description, due, priority, status, isGroup = false) => ({
    id: newId(),
    user_id: userId,
    group_id: isGroup ? groupId : null,
    subject_id: key ? subjectIds[key] : null,
    subject_title: key ? title(key) : null,
    title: name,
    description,
    due_date: due,
    priority,
    status,
    is_group: isGroup,
    source_message_id: null,
    source_task_id: null,
    ...sync(now),
  });
  const courseProject = task('mob', 'Course project: StudyPlan defence', 'Prepare the app, the explanatory note and 7-10 slides.', now + 5 * DAY, 1, 'in_progress');
  await trx('tasks').insert([
    courseProject,
    task('db', 'Lab 5: transactions', 'Show dirty read and lost update examples.', now + 2 * DAY, 1, 'inbox'),
    task('web', 'Group project: REST API documentation', 'Each member documents two endpoints.', now + 4 * DAY, 2, 'inbox', true),
    task('eng', 'Essay "Technology in education"', '250 words, academic style.', now - DAY, 2, 'inbox'),
    task(null, 'Return library books', null, now + 9 * DAY, 3, 'inbox'),
    task('hist', 'Read chapter 5', null, now - 3 * DAY, 3, 'completed'),
  ]);
  await trx('subtasks').insert(['Finish the app', 'Write the explanatory note', 'Make the presentation', 'Install on a phone']
    .map((name, i) => ({ id: newId(), task_id: courseProject.id, user_id: userId, title: name, is_done: i < 2, position: i, ...sync(now) })));

  await trx('lms_courses').insert(GRADES.map(([key, mid, end, fin]) => {
    const s = SUBJECTS.find((x) => x.key === key);
    const items = [
      { name: 'Register Midterm', grade: mid, range: '0–100' },
      { name: 'Register Endterm', grade: end, range: '0–100' },
      { name: 'Final exam', grade: fin, range: '0–100' },
    ];
    return {
      id: newId(),
      user_id: userId,
      source: 'lms',
      lms_course_id: s.lms,
      subject_id: subjectIds[key],
      classification: 'inprogress',
      title: s.title,
      teacher_name: s.teacher,
      credits: 5,
      register_midterm: mid,
      register_endterm: end,
      final_exam: fin,
      total: null,
      grade_items_json: JSON.stringify(items),
      imported_at: now,
      ...sync(now),
    };
  }));

  const deadline = (key, name, module, inDays, eventId) => ({
    id: newId(),
    user_id: userId,
    lms_event_id: eventId,
    lms_course_id: SUBJECTS.find((s) => s.key === key).lms,
    title: name,
    course_title: title(key),
    event_type: 'deadline',
    module_name: module,
    starts_at: now + inDays * DAY,
    duration_min: null,
    location: null,
    url: null,
    is_done: false,
    imported_at: now,
    ...sync(now),
  });
  await trx('lms_events').insert([
    deadline('mob', 'Assignment 3: BLoC is due', 'assign', 1, 990001),
    deadline('db', 'Quiz 4: normal forms', 'quiz', 3, 990002),
    deadline('web', 'Assignment 2: Express API is due', 'assign', 6, 990003),
    deadline('eng', 'Presentation upload', 'assign', 8, 990004),
  ]);

  await trx('lms_materials').insert([
    ['mob', 'Week 7', 'Lecture 7: Flutter navigation', 'file', 880001],
    ['db', 'Week 6', 'Lecture 6: indexes', 'file', 880002],
    ['web', 'Week 5', 'Express.js documentation', 'url', 880003],
  ].map(([key, section, name, type, moduleId]) => ({
    id: newId(),
    user_id: userId,
    lms_module_id: moduleId,
    lms_course_id: SUBJECTS.find((s) => s.key === key).lms,
    course_title: title(key),
    section_title: section,
    title: name,
    material_type: type,
    url: type === 'url' ? 'https://expressjs.com/' : null,
    imported_at: now,
    ...sync(now),
  })));

  const stored = [];
  const rows = MATERIALS.map((m, i) => {
    const fileName = `${newId()}.txt`;
    stored.push({ fileName, content: m.content });
    return {
      id: newId(),
      group_id: groupId,
      uploader_id: userId,
      uploader_name: userName,
      subject_code: m.subject,
      subject_title: title(m.subject),
      title: m.title,
      description: null,
      file_name: m.file,
      file_path: fileName,
      file_size: Buffer.byteLength(m.content),
      file_type: 'txt',
      category: m.category,
      created_at: now - (i + 1) * DAY,
      updated_at: now - (i + 1) * DAY,
    };
  });
  await trx('course_materials').insert(rows);
  return stored;
}

async function writeFiles(stored) {
  await fs.mkdir(env.uploadDir, { recursive: true });
  await Promise.all(stored.map((f) => fs.writeFile(path.join(env.uploadDir, f.fileName), f.content, 'utf8')));
}

// ── College edition demo ────────────────────────────────────────────────────
// A real group from data/timetables, so the public timetable endpoint has lessons for it.
export const COLLEGE_DEMO_GROUP = 'ПО2501';

const COLLEGE_SUBJECTS = [
  {
    id: '700101',
    name: 'Администрирование баз данных',
    teacher: 'Амиралин Т.К.',
    // [date, value (null = absent), theme]
    grades: [
      ['2026-09-08', 85, 'Введение в СУБД'], ['2026-09-15', 92, 'Установка PostgreSQL'],
      ['2026-09-22', 88, 'Роли и права доступа'], ['2026-09-29', null, 'Резервное копирование'],
      ['2026-10-06', 95, 'Восстановление из резервной копии'], ['2026-10-13', 90, 'Индексы и производительность'],
    ],
  },
  {
    id: '700102',
    name: 'Графика и проектирование',
    teacher: 'Сайлаубаева Н.Е.',
    grades: [
      ['2026-09-09', 78, 'Основы композиции'], ['2026-09-16', 82, 'Векторная графика'],
      ['2026-09-30', 75, 'Макет интерфейса'], ['2026-10-07', 80, 'Прототипирование в Figma'],
      ['2026-10-14', 85, 'Защита макета'],
    ],
  },
  {
    id: '700103',
    name: 'Составление алгоритма и создание блок-схемы на основе спецификации программного обеспечения',
    teacher: 'Мартынцов Н.В.',
    grades: [
      ['2026-09-10', 60, 'Линейные алгоритмы'], ['2026-09-17', 55, 'Ветвления'],
      ['2026-09-24', null, 'Циклы'], ['2026-10-01', 45, 'Блок-схемы циклов'],
      ['2026-10-08', 70, 'Массивы'], ['2026-10-15', 62, 'Контрольная работа'],
    ],
  },
  {
    id: '700104',
    name: 'Применение информационно-коммуникационных и цифровых технологий',
    teacher: 'Ахмадиева А.К.',
    grades: [
      ['2026-09-11', 95, 'Облачные сервисы'], ['2026-09-18', 100, 'Электронная почта и этикет'],
      ['2026-10-02', 90, 'Электронное правительство'], ['2026-10-16', 98, 'Цифровая безопасность'],
    ],
  },
  {
    id: '700105',
    name: 'Применение базовых знаний экономики и основ предпринимательства',
    teacher: 'Акубаева Б.А.',
    grades: [
      ['2026-09-12', 80, 'Спрос и предложение'], ['2026-09-26', 74, 'Бизнес-план'],
      ['2026-10-10', 86, 'Налоги для ИП'], ['2026-10-17', 82, 'Презентация бизнес-идеи'],
    ],
  },
];

const round1 = (n) => Math.round(n * 10) / 10;

/** Snapshot in the same shape as `buildSnapshot` (smartnation/sync.js). */
export function buildCollegeDemoSnapshot(now = Date.now()) {
  const subjects = COLLEGE_SUBJECTS.map((s) => {
    const grades = s.grades.map(([date, value, theme]) => ({
      date,
      value,
      label: value == null ? 'Н' : String(value),
      absent: value == null,
      failed: value != null && value < 50,
      theme,
      is_exam: false,
    }));
    const values = grades.filter((g) => g.value != null).map((g) => g.value);
    return {
      id: s.id,
      name: s.name,
      kind: 'Теоретическое обучение',
      teacher: s.teacher,
      grades,
      average: values.length ? round1(values.reduce((a, v) => a + v, 0) / values.length) : null,
      absences: grades.filter((g) => g.absent).length,
    };
  });

  const iso = (ms) => new Date(ms).toISOString();
  const day = (ms) => iso(ms).slice(0, 10);
  const assignment = (id, title, subjectIdx, createdAgo, expiresIn, status, result, closed) => {
    const expires = now + expiresIn * DAY;
    return {
      id: String(id),
      title,
      subject: COLLEGE_SUBJECTS[subjectIdx].name,
      created_at: iso(now - createdAgo * DAY),
      expires_at: iso(expires),
      lesson_date: day(now - createdAgo * DAY),
      status,
      result,
      url: null,
      closed,
      is_current: !closed && (!['Проверено', 'На проверке', 'Выполнено'].includes(status) || expires >= now),
    };
  };
  const assignments = [
    assignment(810001, 'Практическая работа 7: резервное копирование', 0, 2, 3, 'В ожидании', null, false),
    assignment(810002, 'Блок-схема алгоритма сортировки', 2, 1, 5, 'В ожидании', null, false),
    assignment(810003, 'Прототип мобильного приложения', 1, 4, 2, 'На проверке', null, false),
    assignment(810004, 'Практическая работа 5: роли и права', 0, 20, -14, 'Проверено', 92, true),
    assignment(810005, 'Бизнес-план стартапа', 4, 25, -18, 'Проверено', 86, true),
    assignment(810006, 'Контрольная: циклы', 2, 30, -24, 'Проверено', 45, true),
  ].sort((a, b) => String(b.expires_at).localeCompare(String(a.expires_at)));

  return {
    version: 1,
    synced_at: iso(now),
    profile: {
      group: COLLEGE_DEMO_GROUP,
      course: 2,
      qualification: 'Разработчик программного обеспечения',
      curator: 'Мартынцов Н.В.',
    },
    subjects,
    stats: buildStats(subjects),
    assignments,
  };
}

/** Tasks of the college demo (no subjects/LMS rows: grades come from the snapshot). */
async function fillCollegeDemoData(trx, userId, groupId) {
  const now = Date.now();
  const task = (subjectIdx, title, description, due, priority, status, isGroup = false) => ({
    id: newId(),
    user_id: userId,
    group_id: isGroup ? groupId : null,
    subject_id: null,
    subject_title: subjectIdx == null ? null : COLLEGE_SUBJECTS[subjectIdx].name,
    title,
    description,
    due_date: due,
    priority,
    status,
    is_group: isGroup,
    source_message_id: null,
    source_task_id: null,
    ...sync(now),
  });
  await trx('tasks').insert([
    task(0, 'Сдать практическую работу 7', 'Скрипт резервного копирования и отчёт со скриншотами.', now + 3 * DAY, 1, 'in_progress'),
    task(2, 'Нарисовать блок-схему сортировки', 'Пузырьковая сортировка, оформить в draw.io.', now + 5 * DAY, 2, 'inbox'),
    task(1, 'Групповой проект: макет приложения колледжа', 'Каждый делает два экрана в общем файле Figma.', now + 7 * DAY, 2, 'inbox', true),
    task(4, 'Подготовить презентацию бизнес-идеи', '5–7 слайдов, выступление 3 минуты.', now + 10 * DAY, 3, 'inbox', true),
    task(null, 'Принести справку в учебную часть', null, now + 2 * DAY, 3, 'inbox'),
    task(3, 'Пройти тест по цифровой безопасности', null, now - 2 * DAY, 3, 'completed'),
  ]);
}

async function createCollegeDemoAccount() {
  const now = Date.now();
  const userId = newId();
  const groupId = newId();
  await db.transaction(async (trx) => {
    await trx('groups').insert({
      id: groupId,
      title: `${COLLEGE_DEMO_GROUP} (демо)`,
      invite_code: await uniqueInviteCode(trx),
      semester: 1,
      semester_start: '2026-09-01',
      sn_group_name: null,
      created_by: userId,
      created_at: now,
      updated_at: now,
    });
    await trx('users').insert({
      id: userId,
      email: null,
      password_hash: null,
      name: 'Демо-студент',
      role: 'user',
      is_blocked: false,
      is_demo: true,
      edition: 'college',
      sn_iin: null,
      sn_credentials_enc: null,
      sn_group: COLLEGE_DEMO_GROUP,
      group_id: groupId,
      created_at: now,
      updated_at: now,
    });
    await fillCollegeDemoData(trx, userId, groupId);
    await trx('sn_snapshots').insert({
      user_id: userId,
      data: JSON.stringify(buildCollegeDemoSnapshot(now)),
      synced_at: now,
    });
  });
  return buildSession(await db('users').where({ id: userId }).first());
}

/**
 * Creates a demo user with its own group and demo content; returns a normal session.
 * `edition: 'college'` creates a college (SmartNation) demo with a stored snapshot.
 */
export async function createDemoAccount({ edition } = {}) {
  if (edition != null && !['university', 'college'].includes(edition)) {
    throw badRequest('edition must be "university" or "college"');
  }
  if (edition === 'college') return createCollegeDemoAccount();
  const now = Date.now();
  const userId = newId();
  const groupId = newId();
  const name = 'Demo Student';
  const stored = await db.transaction(async (trx) => {
    await trx('groups').insert({
      id: groupId,
      title: 'Demo group',
      invite_code: await uniqueInviteCode(trx),
      semester: 1,
      semester_start: '2026-09-01',
      created_by: userId,
      created_at: now,
      updated_at: now,
    });
    await trx('users').insert({
      id: userId,
      email: null,
      password_hash: null,
      name,
      role: 'user',
      is_blocked: false,
      is_demo: true,
      group_id: groupId,
      created_at: now,
      updated_at: now,
    });
    return fillDemoData(trx, userId, groupId, name);
  });
  await writeFiles(stored);
  return buildSession(await db('users').where({ id: userId }).first());
}

/**
 * Deletes all data of a demo user: synced rows become tombstones (so devices drop
 * them on the next sync) and the user's uploaded materials are removed.
 */
export async function clearDemoData(user) {
  if (!toBool(user.is_demo)) throw forbidden('Only demo accounts can be cleared');
  const now = Date.now();
  const files = await db.transaction(async (trx) => {
    for (const table of SYNC_ORDER) {
      // eslint-disable-next-line no-await-in-loop
      await trx(table).where({ user_id: user.id, is_deleted: false })
        .update({ is_deleted: true, updated_at: now, server_updated_at: now });
    }
    await trx('sn_snapshots').where({ user_id: user.id }).del();
    const materials = await trx('course_materials').where({ uploader_id: user.id }).select('file_path');
    await trx('course_materials').where({ uploader_id: user.id }).del();
    return materials.map((m) => m.file_path);
  });
  await Promise.all(files.map((f) => fs.unlink(path.join(env.uploadDir, path.basename(String(f)))).catch(() => {})));
  return { success: true, server_time: now };
}
