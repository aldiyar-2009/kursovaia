// Finishes the StudyPlan prototype file (JWFKznQL90RPdYUeEg67oB) after the Figma MCP limit:
// 1) rebuilds the List Row component and fixes squashed buttons/chips,
// 2) prototype links on the mobile page, 3) on the admin page,
// 4) colour swatches and type scale on the design-system page.
// Each step is independent: a failure is reported and the next step still runs.

const log = [];
const node = async (id) => figma.getNodeByIdAsync(id);
// Component property value by its display name ("Title" -> key "Title#24:8").
const prop = (inst, name) => {
  const key = Object.keys(inst.componentProperties || {}).find((k) => k.split('#')[0] === name);
  return key ? inst.componentProperties[key].value : undefined;
};
const nav = (id) => ({
  trigger: { type: 'ON_CLICK' },
  actions: [{ type: 'NODE', destinationId: id, navigation: 'NAVIGATE', transition: { type: 'DISSOLVE', easing: { type: 'EASE_OUT' }, duration: 0.2 }, preserveScrollPosition: false }],
});
const back = { trigger: { type: 'ON_CLICK' }, actions: [{ type: 'BACK' }] };
const textIn = (root, chars) => root && root.findOne((n) => n.type === 'TEXT' && n.characters === chars);
async function link(target, dest, label) {
  if (!target) { log.push('  не найдено: ' + label); return; }
  await target.setReactionsAsync([dest === 'BACK' ? back : nav(dest)]);
}

async function step1() {
  const page = await node('1:2');
  await figma.setCurrentPageAsync(page);
  const ds = await node('0:1');
  const prof = await node('11:2');
  const rowSrc = textIn(prof, 'Сервер').parent.parent.parent;
  const cl = rowSrc.clone();
  ds.appendChild(cl);
  const row = figma.createComponentFromNode(cl);
  row.name = 'List Row';
  row.x = 1300; row.y = 1400;
  row.resize(356, row.height);
  const texts = row.findAll((n) => n.type === 'TEXT');
  const chevron = row.children[row.children.length - 1];
  chevron.name = 'Chevron';
  const pT = row.addComponentProperty('Title', 'TEXT', 'Сервер');
  const pS = row.addComponentProperty('Subtitle', 'TEXT', 'http://localhost:3100/api');
  const pSV = row.addComponentProperty('Show subtitle', 'BOOLEAN', true);
  const pCV = row.addComponentProperty('Show chevron', 'BOOLEAN', true);
  texts[0].componentPropertyReferences = { characters: pT };
  texts[1].componentPropertyReferences = { characters: pS };
  texts[1].parent.componentPropertyReferences = { visible: pSV };
  chevron.componentPropertyReferences = { visible: pCV };
  row.description = 'Строка списка внутри группы с рамкой 1 px: заголовок, подпись, шеврон.';

  const old = await node('24:183');
  let swapped = 0;
  if (old) {
    const olds = page.findAll((n) => n.type === 'INSTANCE' && n.mainComponent && n.mainComponent.id === old.id);
    for (const oi of olds) {
      const t = prop(oi, 'Title') || '';
      const s = prop(oi, 'Show subtitle') ? prop(oi, 'Subtitle') : '';
      const rf = oi.parent;
      const hasChev = rf.children.length > 1;
      const par = rf.parent;
      const inst = row.createInstance();
      par.insertChild(par.children.indexOf(rf), inst);
      inst.layoutSizingHorizontal = 'FILL';
      inst.layoutSizingVertical = 'HUG';
      inst.setProperties({ [pT]: t, [pS]: s || ' ', [pSV]: !!s, [pCV]: hasChev });
      inst.name = 'List Row / ' + t;
      rf.remove();
      swapped++;
    }
    old.remove();
  }
  let fixed = 0;
  for (const inst of page.findAll((n) => n.type === 'INSTANCE' && n.mainComponent)) {
    const set = inst.mainComponent.parent;
    const name = set && set.type === 'COMPONENT_SET' ? set.name : inst.mainComponent.name;
    if (!['Button', 'Filter Chip'].includes(name)) continue;
    if (inst.height >= inst.mainComponent.height) continue;
    inst.layoutSizingVertical = 'FIXED';
    inst.resize(inst.width, inst.mainComponent.height);
    fixed++;
  }
  log.push('1. Строки списка заменены: ' + swapped + ', кнопок и чипов выпрямлено: ' + fixed);
}

const F = { guest: '4:2', home: '5:2', sched: '6:2', tasks: '7:2', grades: '8:2', more: '10:2', login: '2:2', signup: '3:2', course: '9:2', profile: '11:2', group: '12:2', materials: '13:2', ann: '14:2', map: '15:2' };

async function step2() {
  const page = await node('1:2');
  await figma.setCurrentPageAsync(page);
  const tabs = { 'Tab/Главная': F.home, 'Tab/Расписание': F.sched, 'Tab/Задания': F.tasks, 'Tab/Оценки': F.grades, 'Tab/Ещё': F.more };
  for (const fid of [F.guest, F.home, F.sched, F.tasks, F.grades, F.more]) {
    const f = await node(fid);
    const bn = f && f.findOne((n) => n.name === 'Bottom Nav');
    if (!bn) { log.push('  нет нижней панели в ' + fid); continue; }
    for (const t of bn.findAll((n) => tabs[n.name])) {
      await t.setReactionsAsync([nav(fid === F.guest && t.name === 'Tab/Главная' ? F.guest : tabs[t.name])]);
    }
  }
  const guest = await node(F.guest);
  const banner = guest.findOne((n) => n.name === 'Banner');
  await link(textIn(banner, 'Войти')?.parent, F.login, 'баннер «Войти»');
  await link(textIn(banner, 'Демо-режим')?.parent, F.home, 'баннер «Демо-режим»');
  for (const fid of [F.login, F.signup]) {
    const f = await node(fid);
    const demo = f.findOne((n) => n.type === 'INSTANCE' && prop(n, 'Label') === 'Попробовать демо-режим');
    await link(demo, F.home, 'демо-кнопка');
    await link(textIn(f, fid === F.login ? 'Регистрация' : 'Вход')?.parent, fid === F.login ? F.signup : F.login, 'переключатель вход/регистрация');
    await link(textIn(f, 'Продолжить без входа')?.parent, F.guest, '«Продолжить без входа»');
  }
  const more = await node(F.more);
  for (const [n, d] of [['Профиль и настройки', F.profile], ['Группа', F.group], ['Материалы', F.materials], ['Объявления', F.ann], ['Карта AITU', F.map]]) {
    await link(more.findOne((x) => x.name === 'List Row / ' + n), d, 'Ещё → ' + n);
  }
  const grades = await node(F.grades);
  await link(textIn(grades, 'Mobile Application Development')?.parent?.parent?.parent, F.course, 'Оценки → Курс');
  for (const fid of [F.course, F.profile, F.group, F.materials, F.ann, F.map]) {
    const f = await node(fid);
    const bar = f && f.children[0];
    await link(bar && bar.children[0], 'BACK', 'назад в ' + fid);
  }
  page.flowStartingPoints = [{ nodeId: F.guest, name: 'Главная (гость)' }];
  log.push('2. Переходы мобильного приложения добавлены');
}

async function step3() {
  const page = await node('1:3');
  await figma.setCurrentPageAsync(page);
  const A = { login: '17:2', dash: '18:2', users: '19:2', userDlg: '20:2', ann: '21:2', annDlg: '22:2' };
  const items = { 'Nav/Сводка': A.dash, 'Nav/Пользователи': A.users, 'Nav/Объявления': A.ann };
  for (const fid of [A.dash, A.users, A.ann]) {
    const sb = (await node(fid)).findOne((n) => n.name === 'Admin Sidebar');
    if (!sb) { log.push('  нет бокового меню в ' + fid); continue; }
    for (const it of sb.findAll((n) => items[n.name])) await it.setReactionsAsync([nav(items[it.name])]);
    await link(textIn(sb, 'Выйти')?.parent, A.login, '«Выйти»');
  }
  await link(textIn(await node(A.login), 'Войти')?.parent, A.dash, 'вход администратора');
  await link(textIn(await node(A.users), 'Добавить пользователя')?.parent, A.userDlg, '«Добавить пользователя»');
  await link(textIn(await node(A.ann), 'Новое объявление')?.parent, A.annDlg, '«Новое объявление»');
  for (const [dlg, list] of [[A.userDlg, A.users], [A.annDlg, A.ann]]) {
    const d = await node(dlg);
    await link(textIn(d, 'Отмена')?.parent, list, 'диалог «Отмена»');
    await link(textIn(d, 'Сохранить')?.parent, list, 'диалог «Сохранить»');
  }
  page.flowStartingPoints = [{ nodeId: A.login, name: 'Админ-панель' }];
  log.push('3. Переходы админ-панели добавлены');
}

async function step4() {
  const ds = await node('0:1');
  await figma.setCurrentPageAsync(ds);
  await figma.loadFontAsync({ family: 'Inter', style: 'Regular' });
  await figma.loadFontAsync({ family: 'Inter', style: 'Semi Bold' });
  const label = (chars, x, y, size = 13, style = 'Regular') => {
    const t = figma.createText();
    t.fontName = { family: 'Inter', style };
    t.fontSize = size;
    t.characters = chars;
    t.x = x; t.y = y;
    ds.appendChild(t);
    return t;
  };
  label('Цвета', 0, 0, 28, 'Semi Bold');
  const cols = await figma.variables.getLocalVariableCollectionsAsync();
  let x = 0;
  for (const c of cols) {
    const vars = [];
    for (const id of c.variableIds) {
      const v = await figma.variables.getVariableByIdAsync(id);
      if (v && v.resolvedType === 'COLOR') vars.push(v);
    }
    if (!vars.length) continue;
    label(c.name, x, 56, 15, 'Semi Bold');
    vars.forEach((v, i) => {
      const r = figma.createRectangle();
      r.resize(40, 40);
      r.cornerRadius = 8;
      r.x = x; r.y = 92 + i * 52;
      r.strokes = [{ type: 'SOLID', color: { r: 0.89, g: 0.89, b: 0.91 } }];
      r.strokeWeight = 1;
      r.fills = [figma.variables.setBoundVariableForPaint({ type: 'SOLID', color: { r: 1, g: 1, b: 1 } }, 'color', v)];
      ds.appendChild(r);
      label(v.name, x + 52, 92 + i * 52 + 12);
    });
    x += 300;
  }
  const styles = await figma.getLocalTextStylesAsync();
  const tx = x + 40;
  label('Типографика', tx, 0, 28, 'Semi Bold');
  let y = 56;
  for (const s of styles) {
    await figma.loadFontAsync(s.fontName);
    const t = figma.createText();
    t.fontName = s.fontName;
    t.characters = s.name + ' — ' + s.fontSize + ' px';
    await t.setTextStyleIdAsync(s.id);
    t.x = tx; t.y = y;
    ds.appendChild(t);
    y += Math.max(32, s.fontSize * 1.6);
  }
  label('Компоненты', 0, 1340, 28, 'Semi Bold');
  log.push('4. Образцы цветов (' + cols.length + ' коллекций) и шрифтов (' + styles.length + ' стилей) добавлены');
}

(async () => {
  for (const [name, fn] of [['Шаг 1', step1], ['Шаг 2', step2], ['Шаг 3', step3], ['Шаг 4', step4]]) {
    try { await fn(); } catch (e) { log.push(name + ' — ошибка: ' + (e && e.message ? e.message : e)); }
  }
  console.log(log.join('\n'));
  figma.closePlugin(log.join(' | '));
})();
