// Remaining use_figma steps for file JWFKznQL90RPdYUeEg67oB ("StudyPlan — прототипы интерфейса").
// Each block below is ONE use_figma call (run in order). Stopped because the Figma MCP
// Starter-plan tool-call limit was reached.

// ===== STEP 1: rebuild List Row component from a full row, re-swap rows, fix button/chip heights =====
const page = await figma.getNodeByIdAsync('1:2');
await figma.setCurrentPageAsync(page);
for (const st of ['Regular','Medium','Semi Bold']) await figma.loadFontAsync({family:'Inter', style: st});
const ds = await figma.getNodeByIdAsync('0:1');
const prof = await figma.getNodeByIdAsync('11:2');
const tn = prof.findOne(n => n.type==='TEXT' && n.characters==='Сервер');
const rowSrc = tn.parent.parent.parent;
const cl = rowSrc.clone(); ds.appendChild(cl);
const row = figma.createComponentFromNode(cl);
row.name = 'List Row'; row.x = 1300; row.y = 1400; row.resize(356, row.height);
const texts = row.findAll(n => n.type==='TEXT');
const chevron = row.children[row.children.length - 1]; chevron.name = 'Chevron';
const pT = row.addComponentProperty('Title','TEXT','Сервер');
const pS = row.addComponentProperty('Subtitle','TEXT','http://localhost:3100/api');
const pSV = row.addComponentProperty('Show subtitle','BOOLEAN', true);
const pCV = row.addComponentProperty('Show chevron','BOOLEAN', true);
texts[0].componentPropertyReferences = {characters: pT};
texts[1].componentPropertyReferences = {characters: pS};
texts[1].parent.componentPropertyReferences = {visible: pSV};
chevron.componentPropertyReferences = {visible: pCV};
row.description = 'Строка списка внутри группы с рамкой 1 px: заголовок, подпись, шеврон.';
const old = await figma.getNodeByIdAsync('24:183');
const olds = page.findAll(n => n.type==='INSTANCE' && n.mainComponent && n.mainComponent.id === '24:183');
for (const oi of olds) {
  const p = oi.componentProperties;
  const t = p['Title#24:8'].value, s = p['Show subtitle#24:10'].value ? p['Subtitle#24:9'].value : '';
  const rf = oi.parent; const hasChev = rf.children.length > 1;
  const par = rf.parent; const idx = par.children.indexOf(rf);
  const inst = row.createInstance(); par.insertChild(idx, inst);
  inst.layoutSizingHorizontal = 'FILL'; inst.layoutSizingVertical = 'HUG';
  inst.setProperties({[pT]: t, [pS]: s || ' ', [pSV]: !!s, [pCV]: hasChev});
  inst.name = 'List Row / ' + t; rf.remove();
}
old.remove();
for (const inst of page.findAll(n => n.type==='INSTANCE' && n.mainComponent && ['Button','Filter Chip'].includes(n.mainComponent.parent?.name))) {
  inst.layoutSizingVertical = 'FIXED'; inst.resize(inst.width, inst.mainComponent.height);
}
return 'ok';

// ===== STEP 2 (mobile page): prototype interactions + flow start =====
// const page = await figma.getNodeByIdAsync('1:2'); await figma.setCurrentPageAsync(page);
// const nav = (id) => ({trigger:{type:'ON_CLICK'}, actions:[{type:'NODE', destinationId:id, navigation:'NAVIGATE', transition:{type:'DISSOLVE', easing:{type:'EASE_OUT'}, duration:0.2}, preserveScrollPosition:false}]});
// const back = {trigger:{type:'ON_CLICK'}, actions:[{type:'BACK'}]};
// const F = {home:'5:2', guest:'4:2', sched:'6:2', tasks:'7:2', grades:'8:2', more:'10:2', login:'2:2', signup:'3:2', course:'9:2', profile:'11:2', group:'12:2', materials:'13:2', ann:'14:2', map:'15:2'};
// const tabs = {'Tab/Главная':F.home,'Tab/Расписание':F.sched,'Tab/Задания':F.tasks,'Tab/Оценки':F.grades,'Tab/Ещё':F.more};
// for (const fid of [F.guest,F.home,F.sched,F.tasks,F.grades,F.more]) { const f = await figma.getNodeByIdAsync(fid);
//   const bn = f.findOne(n => n.name==='Bottom Nav'); for (const t of bn.children) if (tabs[t.name]) await t.setReactionsAsync([nav(fid===F.guest && t.name==='Tab/Главная' ? F.guest : tabs[t.name])]); }
// const guest = await figma.getNodeByIdAsync(F.guest); const banner = guest.findOne(n => n.name==='Banner');
// await banner.findOne(n => n.type==='TEXT' && n.characters==='Войти').parent.setReactionsAsync([nav(F.login)]);
// await banner.findOne(n => n.type==='TEXT' && n.characters==='Демо-режим').parent.setReactionsAsync([nav(F.home)]);
// for (const fid of [F.login, F.signup]) { const f = await figma.getNodeByIdAsync(fid);
//   const demo = f.findOne(n => n.type==='INSTANCE' && n.componentProperties?.['Label#24:0']?.value==='Попробовать демо-режим'); await demo.setReactionsAsync([nav(F.home)]);
//   const seg = f.findOne(n => n.type==='TEXT' && n.characters===(fid===F.login?'Регистрация':'Вход')).parent; await seg.setReactionsAsync([nav(fid===F.login?F.signup:F.login)]);
//   await f.findOne(n => n.type==='TEXT' && n.characters==='Продолжить без входа').parent.setReactionsAsync([nav(F.guest)]); }
// const more = await figma.getNodeByIdAsync(F.more);
// for (const [n, d] of [['Профиль и настройки',F.profile],['Группа',F.group],['Материалы',F.materials],['Объявления',F.ann],['Карта AITU',F.map]]) await more.findOne(x => x.name==='List Row / '+n).setReactionsAsync([nav(d)]);
// const grades = await figma.getNodeByIdAsync(F.grades);
// await grades.findOne(n => n.type==='TEXT' && n.characters==='Mobile Application Development').parent.parent.parent.setReactionsAsync([nav(F.course)]);
// for (const fid of [F.course,F.profile,F.group,F.materials,F.ann,F.map]) { const f = await figma.getNodeByIdAsync(fid); const bar = f.children[0]; await bar.children[0].setReactionsAsync([back]); }
// page.flowStartingPoints = [{nodeId: F.guest, name: 'Главная (гость)'}];

// ===== STEP 3 (admin page): sidebar + login interactions =====
// const page = await figma.getNodeByIdAsync('1:3'); await figma.setCurrentPageAsync(page);
// const A = {login:'17:2', dash:'18:2', users:'19:2', userDlg:'20:2', ann:'21:2', annDlg:'22:2'};
// const items = {'Nav/Сводка':A.dash,'Nav/Пользователи':A.users,'Nav/Объявления':A.ann};
// for (const fid of [A.dash,A.users,A.ann]) { const sb = (await figma.getNodeByIdAsync(fid)).findOne(n => n.name==='Admin Sidebar');
//   for (const it of sb.findAll(n => items[n.name])) await it.setReactionsAsync([nav(items[it.name])]);
//   await sb.findOne(n => n.type==='TEXT' && n.characters==='Выйти').parent.setReactionsAsync([nav(A.login)]); }
// await (await figma.getNodeByIdAsync(A.login)).findOne(n => n.type==='TEXT' && n.characters==='Войти').parent.setReactionsAsync([nav(A.dash)]);
// "Добавить пользователя" -> A.userDlg, "Новое объявление" -> A.annDlg, dialog "Отмена"/"Сохранить" -> back to list frame.
// page.flowStartingPoints = [{nodeId: A.login, name: 'Админ-панель'}];

// ===== STEP 4 (design system page 0:1): colour swatches (light + dark collections), type scale specimens,
// section labels above the components (components already sit at y >= 1400). Then one screenshot per page.
