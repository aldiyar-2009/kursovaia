import bcrypt from 'bcryptjs';
import crypto from 'node:crypto';

/**
 * Demo data: group "ИВТ-21", a headman and a student with a realistic timetable,
 * deadlines and group chat history.
 *   headman@studyplan.dev / password123   (Староста)
 *   student@studyplan.dev / password123   (Студент)
 * Invite code: IVT21A
 * @param {import('knex').Knex} knex
 */
export async function seed(knex) {
  const id = () => crypto.randomUUID();
  const now = Date.now();
  const HOUR = 3_600_000;
  const DAY = 24 * HOUR;

  for (const t of ['chat_messages', 'subtasks', 'tasks', 'lessons', 'subjects', 'users', 'groups']) {
    // eslint-disable-next-line no-await-in-loop
    await knex(t).del();
  }

  const groupId = id();
  const headmanId = id();
  const studentId = id();
  const passwordHash = await bcrypt.hash('password123', 10);

  await knex('groups').insert({
    id: groupId,
    title: 'ИВТ-21',
    invite_code: 'IVT21A',
    semester: 3,
    semester_start: '2026-08-31',
    created_by: headmanId,
    created_at: now,
    updated_at: now,
  });

  await knex('users').insert([
    { id: headmanId, email: 'headman@studyplan.dev', password_hash: passwordHash, name: 'Алина Смирнова', role: 'headman', group_id: groupId, created_at: now, updated_at: now },
    { id: studentId, email: 'student@studyplan.dev', password_hash: passwordHash, name: 'Дмитрий Козлов', role: 'student', group_id: groupId, created_at: now, updated_at: now },
  ]);

  const SUBJECTS = [
    { key: 'db', title: 'Базы данных', teacher: 'Петров А. В.', color: '#6366F1' },
    { key: 'math', title: 'Мат. анализ', teacher: 'Иванова Е. С.', color: '#F59E0B' },
    { key: 'py', title: 'Программирование на Python', teacher: 'Соколов Д. И.', color: '#10B981' },
    { key: 'net', title: 'Компьютерные сети', teacher: 'Морозов К. П.', color: '#06B6D4' },
    { key: 'eng', title: 'Английский язык', teacher: 'Smith J.', color: '#EC4899' },
    { key: 'phys', title: 'Физика', teacher: 'Кузнецова О. Н.', color: '#8B5CF6' },
  ];

  // [subjectKey, day, start, end, room, type, isEvenWeek(null=every), topic]
  const TIMETABLE = [
    ['db', 1, '08:30', '10:00', 'Ауд. 301', 'lecture', null, 'Нормализация отношений'],
    ['math', 1, '10:15', '11:45', 'Ауд. 214', 'practice', null, 'Пределы функций'],
    ['py', 1, '12:00', '13:30', 'Лаб. 105', 'lab', true, 'Работа с файлами'],
    ['net', 2, '10:15', '11:45', 'Ауд. 402', 'lecture', null, 'Модель OSI'],
    ['eng', 2, '12:00', '13:30', 'Ауд. 118', 'practice', null, 'Technical reading'],
    ['phys', 2, '14:00', '15:30', 'Ауд. 220', 'lecture', false, 'Электростатика'],
    ['math', 3, '08:30', '10:00', 'Ауд. 101', 'lecture', null, 'Производная'],
    ['db', 3, '10:15', '11:45', 'Лаб. 307', 'lab', null, 'SQL: JOIN и подзапросы'],
    ['py', 3, '12:00', '13:30', 'Ауд. 305', 'lecture', null, 'ООП в Python'],
    ['net', 4, '08:30', '10:00', 'Лаб. 410', 'lab', null, 'Wireshark: анализ трафика'],
    ['math', 4, '10:15', '11:45', 'Ауд. 214', 'practice', null, 'Исследование функций'],
    ['db', 4, '12:00', '13:30', 'Ауд. 301', 'practice', true, 'ER-диаграммы'],
    ['phys', 4, '14:00', '15:30', 'Лаб. 203', 'lab', false, 'Закон Ома'],
    ['eng', 5, '10:15', '11:45', 'Ауд. 118', 'practice', null, 'Presentations'],
    ['py', 5, '12:00', '13:30', 'Лаб. 105', 'lab', null, 'Тестирование pytest'],
    ['net', 5, '14:00', '15:30', 'Ауд. 402', 'practice', null, 'IP-адресация'],
    ['phys', 6, '10:15', '11:45', 'Ауд. 220', 'practice', null, 'Решение задач'],
  ];

  const subjectIdsByUser = {};
  for (const userId of [headmanId, studentId]) {
    const map = {};
    const subjects = SUBJECTS.map((s) => {
      map[s.key] = id();
      return { id: map[s.key], user_id: userId, title: s.title, teacher_name: s.teacher, color_hex: s.color, is_deleted: false, updated_at: now, server_updated_at: now };
    });
    // eslint-disable-next-line no-await-in-loop
    await knex('subjects').insert(subjects);
    subjectIdsByUser[userId] = map;

    const lessons = TIMETABLE.map(([key, day, start, end, room, type, even, topic]) => ({
      id: id(),
      subject_id: map[key],
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
      is_deleted: false,
      updated_at: now,
      server_updated_at: now,
    }));
    // eslint-disable-next-line no-await-in-loop
    await knex('lessons').insert(lessons);
  }

  const groupTaskId = id();
  const studentTaskId = id();
  const hm = subjectIdsByUser[headmanId];
  const st = subjectIdsByUser[studentId];
  await knex('tasks').insert([
    { id: groupTaskId, user_id: headmanId, group_id: groupId, subject_id: hm.db, subject_title: 'Базы данных', title: 'Лабораторная №3: SQL-запросы', description: 'Выполнить задания 1–12 из методички, оформить отчёт в PDF.', due_date: now + 3 * DAY, priority: 1, status: 'inbox', is_group: true, source_message_id: null, source_task_id: null, is_deleted: false, updated_at: now, server_updated_at: now },
    { id: studentTaskId, user_id: studentId, group_id: null, subject_id: st.math, subject_title: 'Мат. анализ', title: 'Типовой расчёт №2', description: 'Варианты 7, 12, 15. Пределы и производные.', due_date: now + 20 * HOUR, priority: 1, status: 'in_progress', is_group: false, source_message_id: null, source_task_id: null, is_deleted: false, updated_at: now, server_updated_at: now },
    { id: id(), user_id: studentId, group_id: null, subject_id: st.py, subject_title: 'Программирование на Python', title: 'Покрыть модуль тестами', description: null, due_date: now + 6 * DAY, priority: 2, status: 'inbox', is_group: false, source_message_id: null, source_task_id: null, is_deleted: false, updated_at: now, server_updated_at: now },
    { id: id(), user_id: studentId, group_id: null, subject_id: null, subject_title: null, title: 'Купить тетрадь для конспектов', description: null, due_date: null, priority: 3, status: 'inbox', is_group: false, source_message_id: null, source_task_id: null, is_deleted: false, updated_at: now, server_updated_at: now },
    { id: id(), user_id: studentId, group_id: null, subject_id: st.eng, subject_title: 'Английский язык', title: 'Эссе "My future profession"', description: '250 слов', due_date: now - DAY, priority: 2, status: 'inbox', is_group: false, source_message_id: null, source_task_id: null, is_deleted: false, updated_at: now, server_updated_at: now },
  ]);

  await knex('subtasks').insert([
    { id: id(), task_id: studentTaskId, user_id: studentId, title: 'Задача 1–3: пределы', is_done: true, position: 0, is_deleted: false, updated_at: now, server_updated_at: now },
    { id: id(), task_id: studentTaskId, user_id: studentId, title: 'Задача 4–6: производные', is_done: true, position: 1, is_deleted: false, updated_at: now, server_updated_at: now },
    { id: id(), task_id: studentTaskId, user_id: studentId, title: 'Задача 7: исследование функции', is_done: false, position: 2, is_deleted: false, updated_at: now, server_updated_at: now },
    { id: id(), task_id: studentTaskId, user_id: studentId, title: 'Оформить и сдать', is_done: false, position: 3, is_deleted: false, updated_at: now, server_updated_at: now },
  ]);

  const msg = (offsetMin, sender, type, content, payload = null, pinned = false) => ({
    id: id(),
    group_id: groupId,
    sender_id: sender === 'h' ? headmanId : studentId,
    sender_name: sender === 'h' ? 'Алина Смирнова' : 'Дмитрий Козлов',
    message_type: type,
    content,
    payload_json: payload ? JSON.stringify(payload) : null,
    is_pinned: pinned,
    created_at: now - offsetMin * 60_000,
    server_updated_at: now,
  });

  const fridayChange = {
    action: 'move',
    subject_title: 'Компьютерные сети',
    day_of_week: 5,
    start_time: '14:00',
    end_time: '15:30',
    classroom: 'Ауд. 304',
    lesson_type: 'practice',
    note: 'Пара перенесена в другую аудиторию',
  };

  await knex('chat_messages').insert([
    msg(600, 'h', 'text', 'Всем привет! Это чат нашей группы в StudyPlan. Здесь будут все изменения расписания и домашки 📌', null, true),
    msg(420, 's', 'text', 'Привет! А лабу по БД нужно сдавать в печатном виде?'),
    msg(410, 'h', 'text', 'Нет, достаточно PDF. Петров сказал прислать на почту.'),
    msg(300, 'h', 'homework', 'Лабораторная №3: SQL-запросы', {
      task_id: groupTaskId, subject_title: 'Базы данных', title: 'Лабораторная №3: SQL-запросы',
      description: 'Выполнить задания 1–12 из методички, оформить отчёт в PDF.', due_date: now + 3 * DAY, priority: 1,
    }),
    msg(120, 'h', 'schedule_update', 'Изменение в расписании на Пт: «Компьютерные сети» перенесены в Ауд. 304', fridayChange, true),
    msg(30, 's', 'text', 'Спасибо! Добавил себе 👍'),
  ]);
}
