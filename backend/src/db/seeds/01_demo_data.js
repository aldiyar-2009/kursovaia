import bcrypt from 'bcryptjs';
import crypto from 'node:crypto';

/**
 * Demo data (tests and manual `npm run seed` only, never seeded on startup):
 * group "BDA-2601" with two members, a realistic timetable, deadlines and materials.
 *   headman@studyplan.dev / password123   (Староста)
 *   student@studyplan.dev / password123   (Студент)
 * Invite code: AITU26
 * @param {import('knex').Knex} knex
 */
export async function seed(knex) {
  const id = () => crypto.randomUUID();
  const now = Date.now();
  const HOUR = 3_600_000;
  const DAY = 24 * HOUR;

  for (const t of ['course_materials', 'chat_messages', 'subtasks', 'tasks', 'lessons', 'subjects', 'users', 'groups']) {
    // eslint-disable-next-line no-await-in-loop
    await knex(t).del();
  }

  const groupId = id();
  const headmanId = id();
  const studentId = id();
  const passwordHash = await bcrypt.hash('password123', 10);

  await knex('groups').insert({
    id: groupId,
    title: 'BDA-2601',
    invite_code: 'AITU26',
    semester: 1,
    semester_start: '2026-09-01',
    created_by: headmanId,
    created_at: now,
    updated_at: now,
  });

  await knex('users').insert([
    { id: headmanId, email: 'headman@studyplan.dev', password_hash: passwordHash, name: 'Староста', role: 'headman', group_id: groupId, created_at: now, updated_at: now },
    { id: studentId, email: 'student@studyplan.dev', password_hash: passwordHash, name: 'Студент', role: 'student', group_id: groupId, created_at: now, updated_at: now },
  ]);

  const SUBJECTS = [
    { key: 'py', title: 'Introduction to Programming', teacher: 'Кафедра Computer Science', color: '#10B981' },
    { key: 'math', title: 'Calculus 1', teacher: 'Кафедра высшей математики', color: '#6366F1' },
    { key: 'ict', title: 'Information & Comm. Technologies', teacher: 'Кафедра ICT', color: '#06B6D4' },
    { key: 'eng', title: 'Foreign Language', teacher: 'Языковой центр', color: '#EC4899' },
    { key: 'hist', title: 'History of Kazakhstan', teacher: 'Кафедра гуманитарных наук', color: '#F59E0B' },
    { key: 'pe', title: 'Physical Education', teacher: 'Спортивный комплекс', color: '#8B5CF6' },
  ];

  // [subjectKey, day, start, end, room, type, isEvenWeek(null=every), topic]
  const TIMETABLE = [
    ['py', 1, '08:30', '10:00', 'Ауд. C1.2.204', 'lecture', null, 'Введение в алгоритмы и структуры'],
    ['math', 1, '10:15', '11:45', 'Ауд. C1.2.214', 'practice', null, 'Пределы функций и непрерывность'],
    ['py', 1, '12:00', '13:30', 'Лаб. C1.1.105', 'lab', true, 'Работа с файлами и JSON'],
    ['ict', 2, '10:15', '11:45', 'Ауд. C1.3.402', 'lecture', null, 'Сетевая модель OSI и TCP/IP'],
    ['eng', 2, '12:00', '13:30', 'Ауд. C1.2.118', 'practice', null, 'Technical English: Software Engineering'],
    ['hist', 2, '14:00', '15:30', 'Ауд. C1.1.220', 'lecture', false, 'История государственности Казахстана'],
    ['math', 3, '08:30', '10:00', 'Ауд. C1.2.101', 'lecture', null, 'Производная функции и её приложения'],
    ['ict', 3, '10:15', '11:45', 'Лаб. C1.3.307', 'lab', null, 'Базовые команды Linux и bash'],
    ['py', 3, '12:00', '13:30', 'Ауд. C1.2.305', 'lecture', null, 'Объектно-ориентированное программирование'],
    ['ict', 4, '08:30', '10:00', 'Лаб. C1.3.410', 'lab', null, 'Анализ пакетов Wireshark'],
    ['math', 4, '10:15', '11:45', 'Ауд. C1.2.214', 'practice', null, 'Исследование функций на экстремум'],
    ['pe', 4, '12:00', '13:30', 'Спорткомплекс', 'practice', true, 'Общая физическая подготовка'],
    ['eng', 5, '10:15', '11:45', 'Ауд. C1.2.118', 'practice', null, 'Presentations and Academic Writing'],
    ['py', 5, '12:00', '13:30', 'Лаб. C1.1.105', 'lab', null, 'Модульное тестирование pytest'],
    ['hist', 5, '14:00', '15:30', 'Ауд. C1.1.220', 'practice', null, 'Семинар по истории Казахстана'],
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
    { id: groupTaskId, user_id: headmanId, group_id: groupId, subject_id: hm.ict, subject_title: 'Information & Comm. Technologies', title: 'Лабораторная №3: Сети и протоколы', description: 'Выполнить задания 1–12 из методички, оформить отчёт в PDF.', due_date: now + 3 * DAY, priority: 1, status: 'inbox', is_group: true, source_message_id: null, source_task_id: null, is_deleted: false, updated_at: now, server_updated_at: now },
    { id: studentTaskId, user_id: studentId, group_id: null, subject_id: st.math, subject_title: 'Calculus 1', title: 'Типовой расчёт №2: Пределы', description: 'Варианты 7, 12, 15. Пределы и производные.', due_date: now + 20 * HOUR, priority: 1, status: 'in_progress', is_group: false, source_message_id: null, source_task_id: null, is_deleted: false, updated_at: now, server_updated_at: now },
    { id: id(), user_id: studentId, group_id: null, subject_id: st.py, subject_title: 'Introduction to Programming', title: 'Покрыть проект тестами pytest', description: null, due_date: now + 6 * DAY, priority: 2, status: 'inbox', is_group: false, source_message_id: null, source_task_id: null, is_deleted: false, updated_at: now, server_updated_at: now },
    { id: id(), user_id: studentId, group_id: null, subject_id: null, subject_title: null, title: 'Подготовить материалы к семинару', description: null, due_date: null, priority: 3, status: 'inbox', is_group: false, source_message_id: null, source_task_id: null, is_deleted: false, updated_at: now, server_updated_at: now },
    { id: id(), user_id: studentId, group_id: null, subject_id: st.eng, subject_title: 'Foreign Language', title: 'Эссе "AI and Future of Software Engineering"', description: '250 слов', due_date: now - DAY, priority: 2, status: 'inbox', is_group: false, source_message_id: null, source_task_id: null, is_deleted: false, updated_at: now, server_updated_at: now },
  ]);

  await knex('subtasks').insert([
    { id: id(), task_id: studentTaskId, user_id: studentId, title: 'Задача 1–3: пределы', is_done: true, position: 0, is_deleted: false, updated_at: now, server_updated_at: now },
    { id: id(), task_id: studentTaskId, user_id: studentId, title: 'Задача 4–6: производные', is_done: true, position: 1, is_deleted: false, updated_at: now, server_updated_at: now },
    { id: id(), task_id: studentTaskId, user_id: studentId, title: 'Задача 7: исследование функции', is_done: false, position: 2, is_deleted: false, updated_at: now, server_updated_at: now },
    { id: id(), task_id: studentTaskId, user_id: studentId, title: 'Оформить и сдать', is_done: false, position: 3, is_deleted: false, updated_at: now, server_updated_at: now },
  ]);

  await knex('course_materials').insert([
    {
      id: id(),
      group_id: groupId,
      uploader_id: headmanId,
      uploader_name: 'Староста',
      subject_code: 'py',
      subject_title: 'Introduction to Programming',
      title: 'Силлабус и темы лабораторных работ (Python & Algorithms)',
      description: 'Официальный силлабус на 1 семестр. Требования к оформлению отчетов и критерии оценивания.',
      file_name: 'CS101_Programming_Syllabus_2026.pdf',
      file_path: 'cs101_syllabus.pdf',
      file_size: 2450000,
      file_type: 'pdf',
      category: 'syllabus',
      created_at: now - 10 * DAY,
      updated_at: now - 10 * DAY,
    },
    {
      id: id(),
      group_id: groupId,
      uploader_id: headmanId,
      uploader_name: 'Староста',
      subject_code: 'py',
      subject_title: 'Introduction to Programming',
      title: 'Методические указания к Лабораторной работе №3: Работа с файлами и JSON',
      description: 'Задания по чтению/записи структурированных данных, тесты и примеры входных файлов.',
      file_name: 'Lab3_File_IO_JSON_Guidelines.pdf',
      file_path: 'lab3_guide.pdf',
      file_size: 1850000,
      file_type: 'pdf',
      category: 'lab',
      created_at: now - 3 * DAY,
      updated_at: now - 3 * DAY,
    },
    {
      id: id(),
      group_id: groupId,
      uploader_id: headmanId,
      uploader_name: 'Староста',
      subject_code: 'math',
      subject_title: 'Calculus 1',
      title: 'Лекция 4–6: Пределы последовательностей и функций, производные',
      description: 'Конспект лекций кафедры высшей математики с разобранными примерами.',
      file_name: 'Calculus1_Lectures_Limits_Derivatives.pdf',
      file_path: 'calc1_lectures.pdf',
      file_size: 4200000,
      file_type: 'pdf',
      category: 'lecture',
      created_at: now - 7 * DAY,
      updated_at: now - 7 * DAY,
    },
    {
      id: id(),
      group_id: groupId,
      uploader_id: studentId,
      uploader_name: 'Студент',
      subject_code: 'math',
      subject_title: 'Calculus 1',
      title: 'Таблица производных и эквивалентных бесконечно малых (шпаргалка)',
      description: 'Удобная таблица формул для решения типовых расчетов и подготовки к Midterm.',
      file_name: 'Calculus_Formulas_CheatSheet.pdf',
      file_path: 'calc_cheatsheet.pdf',
      file_size: 780000,
      file_type: 'pdf',
      category: 'assignment',
      created_at: now - 2 * DAY,
      updated_at: now - 2 * DAY,
    },
    {
      id: id(),
      group_id: groupId,
      uploader_id: headmanId,
      uploader_name: 'Староста',
      subject_code: 'ict',
      subject_title: 'Information & Comm. Technologies',
      title: 'Сетевая архитектура OSI и TCP/IP: Лабораторный практикум Wireshark',
      description: 'Пошаговое руководство по перехвату пакетов и анализу трафика в локальной сети.',
      file_name: 'ICT_Lab_Wireshark_Protocol_Analysis.pdf',
      file_path: 'ict_wireshark.pdf',
      file_size: 3100000,
      file_type: 'pdf',
      category: 'lab',
      created_at: now - 5 * DAY,
      updated_at: now - 5 * DAY,
    },
    {
      id: id(),
      group_id: groupId,
      uploader_id: studentId,
      uploader_name: 'Студент',
      subject_code: 'eng',
      subject_title: 'Foreign Language',
      title: 'Academic Writing & Tech Presentation Slides Template',
      description: 'Шаблон презентации для защиты проектных работ и структура эссе.',
      file_name: 'Tech_Presentation_Template_AITU.pptx',
      file_path: 'presentation_template.pptx',
      file_size: 1950000,
      file_type: 'pptx',
      category: 'assignment',
      created_at: now - 4 * DAY,
      updated_at: now - 4 * DAY,
    },
    {
      id: id(),
      group_id: groupId,
      uploader_id: headmanId,
      uploader_name: 'Староста',
      subject_code: 'hist',
      subject_title: 'History of Kazakhstan',
      title: 'Вопросы и тезисы для подготовки к рубежному контролю (РК-1)',
      description: 'Основные даты, события и терминология для подготовки к тестированию.',
      file_name: 'History_RK1_Exam_Preparation.pdf',
      file_path: 'history_rk1.pdf',
      file_size: 1100000,
      file_type: 'pdf',
      category: 'assignment',
      created_at: now - 8 * DAY,
      updated_at: now - 8 * DAY,
    },
  ]);
}

