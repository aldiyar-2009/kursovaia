// Defence presentation (7–10 slides) for the StudyPlan course project.
// Run: NODE_PATH=<dir with node_modules/pptxgenjs> node build_slides.cjs <out.pptx>
const fs = require('fs');
const path = require('path');
const pptxgen = require('pptxgenjs');

const OUT = process.argv[2] || path.join(__dirname, 'StudyPlan_presentation.pptx');
const FIG = path.join(__dirname, 'figures');
const SHOT = path.join(__dirname, '..', 'screenshots');

// Same neutral palette as the app (app_palette.dart) with its blue accent.
const COL = {
  ink: '18181B', paper: 'FFFFFF', muted: 'F4F4F5', border: 'E4E4E7',
  text2: '52525B', accent: '2563EB', warnBg: 'FBF1DE', ok: '146C37',
};
const FONT = 'Arial';

const pres = new pptxgen();
pres.layout = 'LAYOUT_WIDE'; // 13.33 x 7.5 in
pres.author = 'Абдышев А.Б.';
pres.title = 'StudyPlan — защита курсового проекта';
pres.theme = { headFontFace: FONT, bodyFontFace: FONT };

pres.defineSlideMaster({
  title: 'DARK',
  background: { color: COL.ink },
});
pres.defineSlideMaster({
  title: 'CONTENT',
  background: { color: COL.paper },
  objects: [
    { text: { text: 'StudyPlan · курсовой проект ПМ07', options: { x: 0.6, y: 7.0, w: 6, h: 0.3, fontSize: 10, color: '71717A', fontFace: FONT } } },
  ],
  slideNumber: { x: 12.3, y: 7.0, w: 0.5, h: 0.3, fontSize: 10, color: '71717A', fontFace: FONT },
});

const W = 13.33;
const title = (s, t) => s.addText(t, { x: 0.6, y: 0.4, w: W - 1.2, h: 0.8, fontSize: 32, bold: true, color: COL.ink, fontFace: FONT, margin: 0, isTextBox: true });
const lead = (s, t, y = 1.2) => s.addText(t, { x: 0.6, y, w: W - 1.2, h: 0.5, fontSize: 16, color: COL.text2, fontFace: FONT, margin: 0, isTextBox: true });
const pngSize = (f) => { const b = fs.readFileSync(f); return { w: b.readUInt32BE(16), h: b.readUInt32BE(20) }; };
/** Image fitted into a box (keeps aspect ratio), centred horizontally in it. */
function img(s, file, x, y, w, h, opts = {}) {
  const { w: pw, h: ph } = pngSize(file);
  let iw = w, ih = (w * ph) / pw;
  if (ih > h) { ih = h; iw = (h * pw) / ph; }
  s.addImage({ path: file, x: x + (w - iw) / 2, y, w: iw, h: ih, ...opts });
  if (opts.frame) s.addShape(pres.shapes.RECTANGLE, { x: x + (w - iw) / 2, y, w: iw, h: ih, fill: { type: 'none' }, line: { color: COL.border, width: 1 } });
  return { iw, ih, ix: x + (w - iw) / 2 };
}
function numberDot(s, n, x, y, d = 0.5) {
  s.addShape(pres.shapes.OVAL, { x, y, w: d, h: d, fill: { color: COL.accent }, line: { color: COL.accent } });
  s.addText(String(n), { x, y, w: d, h: d, fontSize: 16, bold: true, color: COL.paper, align: 'center', valign: 'middle', fontFace: FONT, margin: 0, isTextBox: true });
}
function bullets(s, items, x, y, w, h, size = 16) {
  s.addText(items.map((t, i) => ({ text: t, options: { bullet: true, breakLine: i < items.length - 1 } })), {
    x, y, w, h, fontSize: size, color: COL.ink, fontFace: FONT, valign: 'top', paraSpaceAfter: 8, margin: 0, isTextBox: true,
  });
}
function card(s, x, y, w, h, head, body) {
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y, w, h, fill: { color: COL.muted }, line: { color: COL.border, width: 1 }, rectRadius: 0.08 });
  s.addText(head, { x: x + 0.25, y: y + 0.2, w: w - 0.5, h: 0.45, fontSize: 18, bold: true, color: COL.ink, fontFace: FONT, margin: 0, isTextBox: true });
  s.addText(body, { x: x + 0.25, y: y + 0.7, w: w - 0.5, h: h - 0.85, fontSize: 14, color: COL.text2, fontFace: FONT, valign: 'top', margin: 0, isTextBox: true });
}

// 1. Title
{
  const s = pres.addSlide({ masterName: 'DARK' });
  s.addText('Колледж ТОО «Astana IT University» · 06130100 «Программное обеспечение» · ПМ07 Разработка мобильных приложений',
    { x: 0.8, y: 0.6, w: 11.7, h: 0.5, fontSize: 14, color: 'A1A1AA', fontFace: FONT, margin: 0, isTextBox: true });
  s.addText('StudyPlan', { x: 0.8, y: 1.9, w: 11.7, h: 1.0, fontSize: 54, bold: true, color: COL.paper, fontFace: FONT, margin: 0, isTextBox: true });
  s.addText('Разработка мобильного приложения для формирования персонального учебного расписания и контроля дедлайнов',
    { x: 0.8, y: 3.0, w: 10.5, h: 1.1, fontSize: 24, color: 'E4E4E7', fontFace: FONT, margin: 0, isTextBox: true });
  s.addText([
    { text: 'Студент: Абдышев А.Б., группа ПО-2406', options: { breakLine: true } },
    { text: 'Преподаватели: Тілеулес Д.Н., Темірке С.Ф.', options: { breakLine: true } },
    { text: 'Астана, 2026' },
  ], { x: 0.8, y: 5.0, w: 8, h: 1.4, fontSize: 18, color: 'D4D4D8', fontFace: FONT, paraSpaceAfter: 6, margin: 0, isTextBox: true });
  img(s, path.join(SHOT, 'app', '02_demo_home.png'), 10.3, 4.0, 2.3, 3.2);
}

// 2. Goal and tasks
{
  const s = pres.addSlide({ masterName: 'CONTENT' });
  title(s, 'Цель и задачи проекта');
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 0.6, y: 1.35, w: W - 1.2, h: 1.15, fill: { color: COL.warnBg }, line: { color: COL.warnBg }, rectRadius: 0.08 });
  s.addText('Цель — клиент-серверная система: мобильное приложение для расписания, дедлайнов и прогноза оценок, сервер с REST API и базой данных, веб-панель администратора',
    { x: 0.9, y: 1.45, w: W - 1.8, h: 0.95, fontSize: 18, color: COL.ink, fontFace: FONT, valign: 'middle', margin: 0, isTextBox: true });
  const tasks = [
    'Проанализировать предметную область и аналоги',
    'Обосновать выбор технологий',
    'Спроектировать структуру, базу данных, API и роли',
    'Реализовать мобильное приложение: гость, демо, синхронизация, LMS',
    'Реализовать веб-панель администратора',
    'Подготовить прототипы Figma, протестировать, установить на смартфон',
  ];
  tasks.forEach((t, i) => {
    const col = i % 2, row = Math.floor(i / 2);
    const x = 0.6 + col * 6.2, y = 2.95 + row * 1.25;
    numberDot(s, i + 1, x, y + 0.05);
    s.addText(t, { x: x + 0.7, y, w: 5.3, h: 0.9, fontSize: 16, color: COL.ink, fontFace: FONT, valign: 'middle', margin: 0, isTextBox: true });
  });
}

// 3. Architecture
{
  const s = pres.addSlide({ masterName: 'CONTENT' });
  title(s, 'Архитектура: клиент – сервер');
  img(s, path.join(FIG, 'fig_2_1_structure.png'), 0.6, 1.4, 7.9, 5.3, { frame: true });
  bullets(s, [
    'Мобильное приложение — Flutter (Android, iOS, Windows, Web), локальная БД Drift, работа без сети',
    'Сервер — Node.js, Express 5, Knex; JWT, проверка ролей и блокировки',
    'Панель администратора — HTML, CSS, JavaScript по адресу /admin',
    'База данных — PostgreSQL (Supabase), доступ только через REST API',
  ], 8.9, 1.5, 3.85, 5.2, 15);
}

// 4. Database and API
{
  const s = pres.addSlide({ masterName: 'CONTENT' });
  title(s, 'База данных и REST API');
  const stats = [['11', 'таблиц PostgreSQL'], ['30', 'маршрутов API'], ['4', 'роли доступа']];
  stats.forEach(([n, l], i) => {
    const x = 0.6 + i * 2.15;
    s.addText(n, { x, y: 1.45, w: 2, h: 0.9, fontSize: 44, bold: true, color: COL.accent, fontFace: FONT, margin: 0, isTextBox: true });
    s.addText(l, { x, y: 2.35, w: 2, h: 0.4, fontSize: 14, color: COL.text2, fontFace: FONT, margin: 0, isTextBox: true });
  });
  bullets(s, [
    'users: роль user | admin, is_blocked, is_demo',
    'announcements: объявления с публикацией',
    'subjects, lessons, tasks, lms_* — синхронизация LWW',
    'JSON, заголовок Authorization: Bearer <JWT>',
    'Ошибки: { error: { code, message } } — 400, 401, 403 USER_BLOCKED, 404, 409, 429',
  ], 0.6, 3.1, 6.2, 3.6, 15);
  img(s, path.join(FIG, 'fig_2_2_er.png'), 7.1, 1.35, 5.6, 5.5, { frame: true });
}

// 5. Mobile app
{
  const s = pres.addSlide({ masterName: 'CONTENT' });
  title(s, 'Мобильное приложение');
  lead(s, 'Все вкладки доступны сразу; данные хранятся на устройстве и синхронизируются с сервером');
  const shots = [['02_demo_home.png', 'Главная: пары, объявления, дедлайны'], ['04_tasks.png', 'Задания с фильтрами'], ['05_grades.png', 'Оценки, GPA, стипендия'], ['06_more.png', 'Ещё: группа, материалы, LMS']];
  shots.forEach(([f, c], i) => {
    const x = 0.6 + i * 3.08;
    const r = img(s, path.join(SHOT, 'app', f), x, 1.85, 2.9, 4.5, { frame: true });
    s.addText(c, { x, y: 1.85 + r.ih + 0.1, w: 2.9, h: 0.5, fontSize: 13, color: COL.text2, align: 'center', fontFace: FONT, margin: 0, isTextBox: true });
  });
}

// 6. Guest and demo mode
{
  const s = pres.addSlide({ masterName: 'CONTENT' });
  title(s, 'Гостевой и демо-режим');
  img(s, path.join(SHOT, 'app', '01_guest_home.png'), 0.6, 1.4, 2.6, 5.4, { frame: true });
  img(s, path.join(SHOT, 'app', '00_auth.png'), 3.45, 1.4, 2.6, 5.4, { frame: true });
  const steps = [
    ['Без регистрации', 'Плашка «Войдите или откройте демо-режим», данные остаются на устройстве'],
    ['Демо-аккаунт', 'POST /api/auth/demo создаёт аккаунт с оценками, дедлайнами и файлами; изменения сохраняются в БД'],
    ['Очистить данные', 'Кнопка в профиле удаляет примерные данные на всех устройствах'],
    ['Свой аккаунт', 'После входа гостевые данные переносятся в аккаунт и синхронизируются'],
  ];
  steps.forEach(([h, b], i) => {
    const y = 1.45 + i * 1.32;
    numberDot(s, i + 1, 6.5, y);
    s.addText(h, { x: 7.2, y: y - 0.05, w: 5.5, h: 0.4, fontSize: 17, bold: true, color: COL.ink, fontFace: FONT, margin: 0, isTextBox: true });
    s.addText(b, { x: 7.2, y: y + 0.38, w: 5.5, h: 0.75, fontSize: 14, color: COL.text2, fontFace: FONT, valign: 'top', margin: 0, isTextBox: true });
  });
}

// 7. Admin panel
{
  const s = pres.addSlide({ masterName: 'CONTENT' });
  title(s, 'Веб-панель администратора');
  img(s, path.join(SHOT, 'admin', '03_users.png'), 0.6, 1.4, 7.6, 4.8, { frame: true });
  card(s, 8.6, 1.4, 4.1, 1.6, 'Пользователи', 'Список, поиск, добавление, изменение, роль user | admin, блокировка');
  card(s, 8.6, 3.2, 4.1, 1.6, 'Объявления', 'Создание, изменение, удаление, публикация и снятие с публикации');
  card(s, 8.6, 5.0, 4.1, 1.4, 'Безопасность', 'Вход только с ролью admin; заблокированный пользователь получает 403');
}

// 8. Figma (if exported) — prototypes
const figma = path.join(FIG, 'fig_3_10_figma.png');
if (fs.existsSync(figma)) {
  const s = pres.addSlide({ masterName: 'CONTENT' });
  title(s, 'Прототипы интерфейса в Figma');
  lead(s, 'Дизайн-система (переменные, стили, компоненты), 14 экранов приложения и 6 экранов панели');
  img(s, figma, 0.6, 1.85, W - 1.2, 4.9, { frame: true });
}

// 9. Testing and installation
{
  const s = pres.addSlide({ masterName: 'CONTENT' });
  title(s, 'Тестирование и установка');
  const stats = [['74', 'тестов сервера', 'API, роли, блокировка, демо'], ['277', 'тестов клиента', 'экраны, синхронизация, LMS'], ['12', 'ручных сценариев', 'на Android и в браузере']];
  stats.forEach(([n, l, d], i) => {
    const x = 0.6 + i * 4.1;
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y: 1.4, w: 3.8, h: 2.3, fill: { color: COL.muted }, line: { color: COL.border, width: 1 }, rectRadius: 0.08 });
    s.addText(n, { x: x + 0.3, y: 1.55, w: 3.2, h: 1.0, fontSize: 54, bold: true, color: COL.accent, fontFace: FONT, margin: 0, isTextBox: true });
    s.addText(l, { x: x + 0.3, y: 2.55, w: 3.2, h: 0.45, fontSize: 18, bold: true, color: COL.ink, fontFace: FONT, margin: 0, isTextBox: true });
    s.addText(d, { x: x + 0.3, y: 3.0, w: 3.2, h: 0.5, fontSize: 14, color: COL.text2, fontFace: FONT, margin: 0, isTextBox: true });
  });
  s.addText('Установка на смартфон', { x: 0.6, y: 4.1, w: 6, h: 0.45, fontSize: 20, bold: true, color: COL.ink, fontFace: FONT, margin: 0, isTextBox: true });
  bullets(s, [
    'Сервер: npm start — миграции применяются автоматически, в консоли QR-код',
    'Приложение: flutter build apk --release, установка APK на Android',
    'Сканирование QR-кода открывает приложение и подключает его к серверу',
  ], 0.6, 4.65, 12, 2.1, 16);
}

// 10. Results
{
  const s = pres.addSlide({ masterName: 'DARK' });
  s.addText('Итоги', { x: 0.8, y: 0.6, w: 11.7, h: 0.9, fontSize: 40, bold: true, color: COL.paper, fontFace: FONT, margin: 0, isTextBox: true });
  const cols = [
    ['Достигнуто', ['Мобильное приложение, сервер, БД и панель администратора', 'Роли, блокировка, объявления, гость и демо-режим', 'Прототипы Figma, 351 автотест']],
    ['Практическая значимость', ['Готово к использованию студентами колледжа', 'Работает без сети, импортирует данные из LMS', 'Администратор управляет системой из браузера']],
    ['Развитие', ['Публикация в Google Play и App Store', 'Push-уведомления об объявлениях', 'Журнал действий администратора']],
  ];
  cols.forEach(([h, items], i) => {
    const x = 0.8 + i * 4.0;
    s.addText(h, { x, y: 1.9, w: 3.7, h: 0.5, fontSize: 20, bold: true, color: '93C5FD', fontFace: FONT, margin: 0, isTextBox: true });
    s.addText(items.map((t, k) => ({ text: t, options: { bullet: true, breakLine: k < items.length - 1 } })),
      { x, y: 2.55, w: 3.7, h: 3.6, fontSize: 16, color: 'E4E4E7', fontFace: FONT, valign: 'top', paraSpaceAfter: 10, margin: 0, isTextBox: true });
  });
  s.addText('Спасибо за внимание!', { x: 0.8, y: 6.4, w: 11.7, h: 0.6, fontSize: 22, color: COL.paper, fontFace: FONT, margin: 0, isTextBox: true });
}

pres.writeFile({ fileName: OUT }).then((f) => console.log('written', f));
