// StudyPlan admin panel: plain JS SPA over the backend REST API (/api/admin/*).
const TOKEN_KEY = 'studyplan.admin.token';
const API = '/api';

const state = { token: null, me: null, users: [], announcements: [], editingUserId: null, editingAnnouncementId: null };

const $ = (sel) => document.querySelector(sel);

function loadToken() {
  try { return localStorage.getItem(TOKEN_KEY); } catch { return null; }
}
function saveToken(token) {
  try {
    if (token) localStorage.setItem(TOKEN_KEY, token);
    else localStorage.removeItem(TOKEN_KEY);
  } catch { /* storage unavailable: session lasts until reload */ }
}

const ERROR_TEXT = {
  UNAUTHORIZED: 'Неверный email или пароль',
  USER_BLOCKED: 'Аккаунт заблокирован',
  FORBIDDEN: 'Недостаточно прав',
  CONFLICT: 'Такой email уже зарегистрирован',
  NOT_FOUND: 'Запись не найдена',
  TOO_MANY_REQUESTS: 'Слишком много запросов, попробуйте позже',
};

class ApiError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

/** fetch wrapper: JSON in/out, Bearer token, `{error: {code, message}}` → ApiError. */
async function api(method, path, body) {
  let res;
  try {
    res = await fetch(API + path, {
      method,
      headers: {
        'Content-Type': 'application/json',
        ...(state.token ? { Authorization: `Bearer ${state.token}` } : {}),
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
  } catch {
    throw new ApiError(0, 'NETWORK', 'Нет соединения с сервером');
  }
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const code = data?.error?.code ?? 'INTERNAL';
    const err = new ApiError(res.status, code, ERROR_TEXT[code] ?? data?.error?.message ?? 'Ошибка сервера');
    // Expired session or revoked rights inside the app: back to the login screen.
    if (state.token && (res.status === 401 || code === 'USER_BLOCKED')) logout(err.message);
    throw err;
  }
  return data;
}

function toast(text) {
  const el = $('#toast');
  el.textContent = text;
  el.hidden = false;
  clearTimeout(toast.timer);
  toast.timer = setTimeout(() => { el.hidden = true; }, 2500);
}

const fmtDate = (ms) => (ms ? new Date(Number(ms)).toLocaleString('ru-RU', { dateStyle: 'short', timeStyle: 'short' }) : '—');

function el(tag, attrs = {}, ...children) {
  const node = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (k === 'class') node.className = v;
    else if (k.startsWith('on')) node.addEventListener(k.slice(2), v);
    else if (v !== false && v != null) node.setAttribute(k, v === true ? '' : v);
  }
  for (const c of children.flat()) if (c != null) node.append(c instanceof Node ? c : String(c));
  return node;
}

// ------------------------------------------------------------------ auth

function showLogin(message = '') {
  $('#app-view').hidden = true;
  $('#login-view').hidden = false;
  $('#login-error').textContent = message;
}

function logout(message = '') {
  state.token = null;
  state.me = null;
  saveToken(null);
  showLogin(message);
}

async function startSession(token) {
  state.token = token;
  const session = await api('GET', '/auth/me');
  if (session.user.role !== 'admin') {
    logout('Этот аккаунт не является администратором');
    return;
  }
  state.me = session.user;
  saveToken(token);
  $('#me-name').textContent = `${session.user.name} · ${session.user.email}`;
  $('#login-view').hidden = true;
  $('#app-view').hidden = false;
  openView(location.hash.slice(1) || 'dashboard');
}

$('#login-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  const form = new FormData(e.target);
  $('#login-error').textContent = '';
  try {
    const session = await api('POST', '/auth/login', { email: form.get('email'), password: form.get('password') });
    await startSession(session.token);
  } catch (err) {
    $('#login-error').textContent = err.message;
  }
});

$('#logout').addEventListener('click', () => logout());

// ------------------------------------------------------------------ navigation

const VIEWS = { dashboard: loadStats, users: loadUsers, announcements: loadAnnouncements };

function openView(name) {
  if (!VIEWS[name]) name = 'dashboard';
  for (const v of Object.keys(VIEWS)) $(`#view-${v}`).hidden = v !== name;
  document.querySelectorAll('.nav-item').forEach((b) => b.classList.toggle('active', b.dataset.view === name));
  if (location.hash.slice(1) !== name) history.replaceState(null, '', `#${name}`);
  VIEWS[name]().catch((err) => toast(err.message));
}

document.querySelectorAll('.nav-item').forEach((b) => b.addEventListener('click', () => openView(b.dataset.view)));

// ------------------------------------------------------------------ dashboard

async function loadStats() {
  const s = await api('GET', '/admin/stats');
  const items = [
    ['Пользователи', s.users], ['Администраторы', s.admins], ['Заблокированы', s.blocked],
    ['Демо-аккаунты', s.demo], ['Группы', s.groups], ['Задания', s.tasks],
    ['Объявления', s.announcements], ['Опубликовано', s.published],
  ];
  $('#stats').replaceChildren(...items.map(([label, value]) =>
    el('div', { class: 'stat' }, el('div', { class: 'value' }, value), el('div', { class: 'label' }, label))));
}

// ------------------------------------------------------------------ users

let searchTimer;
async function loadUsers() {
  const params = new URLSearchParams();
  const q = $('#user-search').value.trim();
  if (q) params.set('q', q);
  if ($('#user-role-filter').value) params.set('role', $('#user-role-filter').value);
  if ($('#user-blocked-filter').value) params.set('blocked', $('#user-blocked-filter').value);
  const { users } = await api('GET', `/admin/users?${params}`);
  state.users = users;
  renderUsers();
}

function renderUsers() {
  const body = $('#users-body');
  if (!state.users.length) {
    body.replaceChildren(el('tr', {}, el('td', { colspan: 7, class: 'empty' }, 'Пользователи не найдены')));
    return;
  }
  body.replaceChildren(...state.users.map((u) => {
    const self = u.id === state.me.id;
    const status = u.is_blocked
      ? el('span', { class: 'badge bad' }, 'Заблокирован')
      : el('span', { class: 'badge ok' }, 'Активен');
    return el('tr', {},
      el('td', {}, u.name, u.is_demo ? ' ' : null, u.is_demo ? el('span', { class: 'badge warn' }, 'демо') : null),
      el('td', {}, u.email ?? '—'),
      el('td', {}, u.role === 'admin' ? 'Администратор' : 'Пользователь'),
      el('td', {}, u.group_title ?? '—'),
      el('td', {}, status),
      el('td', { class: 'nowrap' }, u.created_at ? new Date(Number(u.created_at)).toLocaleDateString('ru-RU') : '—'),
      el('td', { class: 'actions' },
        el('button', { class: 'btn small', onclick: () => openUserDialog(u) }, 'Изменить'),
        el('button', {
          class: `btn small ${u.is_blocked ? '' : 'danger'}`,
          disabled: self,
          title: self ? 'Нельзя заблокировать себя' : null,
          onclick: () => toggleBlock(u),
        }, u.is_blocked ? 'Разблокировать' : 'Заблокировать')));
  }));
}

async function toggleBlock(u) {
  if (!u.is_blocked && !confirm(`Заблокировать «${u.name}»? Пользователь не сможет войти.`)) return;
  try {
    await api('POST', `/admin/users/${u.id}/${u.is_blocked ? 'unblock' : 'block'}`);
    toast(u.is_blocked ? 'Пользователь разблокирован' : 'Пользователь заблокирован');
    await loadUsers();
  } catch (err) {
    toast(err.message);
  }
}

function openUserDialog(user = null) {
  state.editingUserId = user?.id ?? null;
  const form = $('#user-form');
  form.reset();
  form.querySelector('.error').textContent = '';
  $('#user-dialog-title').textContent = user ? 'Изменить пользователя' : 'Новый пользователь';
  $('#password-label').textContent = user ? 'Новый пароль (необязательно)' : 'Пароль';
  form.elements.password.required = !user;
  form.elements.name.value = user?.name ?? '';
  form.elements.email.value = user?.email ?? '';
  // Demo accounts have no email; it stays optional for them.
  form.elements.email.required = !user || Boolean(user.email);
  form.elements.role.value = user?.role ?? 'user';
  form.elements.role.disabled = user?.id === state.me.id;
  $('#user-dialog').showModal();
}

$('#add-user').addEventListener('click', () => openUserDialog());
$('#user-search').addEventListener('input', () => {
  clearTimeout(searchTimer);
  searchTimer = setTimeout(() => loadUsers().catch((err) => toast(err.message)), 250);
});
$('#user-role-filter').addEventListener('change', () => loadUsers().catch((err) => toast(err.message)));
$('#user-blocked-filter').addEventListener('change', () => loadUsers().catch((err) => toast(err.message)));

$('#user-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  const form = e.target;
  const payload = { name: form.elements.name.value };
  if (form.elements.email.value.trim()) payload.email = form.elements.email.value;
  if (!form.elements.role.disabled) payload.role = form.elements.role.value;
  if (form.elements.password.value) payload.password = form.elements.password.value;
  try {
    if (state.editingUserId) await api('PATCH', `/admin/users/${state.editingUserId}`, payload);
    else await api('POST', '/admin/users', payload);
    $('#user-dialog').close();
    toast('Сохранено');
    await loadUsers();
  } catch (err) {
    form.querySelector('.error').textContent = err.message;
  }
});

// ------------------------------------------------------------------ announcements

async function loadAnnouncements() {
  const { announcements } = await api('GET', '/admin/announcements');
  state.announcements = announcements;
  renderAnnouncements();
}

function renderAnnouncements() {
  const list = $('#announcements-list');
  if (!state.announcements.length) {
    list.replaceChildren(el('div', { class: 'empty' }, 'Объявлений пока нет'));
    return;
  }
  list.replaceChildren(...state.announcements.map((a) => el('article', { class: 'row' },
    el('div', { class: 'row-head' },
      el('span', { class: 'row-title' }, a.title),
      a.is_published ? el('span', { class: 'badge ok' }, 'Опубликовано') : el('span', { class: 'badge' }, 'Черновик')),
    el('div', { class: 'row-body' }, a.body),
    el('div', { class: 'row-meta' },
      `Автор: ${a.author_name ?? '—'} · создано ${fmtDate(a.created_at)}`,
      a.is_published ? ` · опубликовано ${fmtDate(a.published_at)}` : ''),
    el('div', { class: 'row-actions' },
      el('button', { class: 'btn small', onclick: () => togglePublish(a) }, a.is_published ? 'Снять с публикации' : 'Опубликовать'),
      el('button', { class: 'btn small', onclick: () => openAnnouncementDialog(a) }, 'Изменить'),
      el('button', { class: 'btn small danger', onclick: () => deleteAnnouncement(a) }, 'Удалить')))));
}

async function togglePublish(a) {
  try {
    await api('POST', `/admin/announcements/${a.id}/${a.is_published ? 'unpublish' : 'publish'}`);
    toast(a.is_published ? 'Снято с публикации' : 'Опубликовано');
    await loadAnnouncements();
  } catch (err) {
    toast(err.message);
  }
}

async function deleteAnnouncement(a) {
  if (!confirm(`Удалить объявление «${a.title}»?`)) return;
  try {
    await api('DELETE', `/admin/announcements/${a.id}`);
    toast('Удалено');
    await loadAnnouncements();
  } catch (err) {
    toast(err.message);
  }
}

function openAnnouncementDialog(a = null) {
  state.editingAnnouncementId = a?.id ?? null;
  const form = $('#announcement-form');
  form.reset();
  form.querySelector('.error').textContent = '';
  $('#announcement-dialog-title').textContent = a ? 'Изменить объявление' : 'Новое объявление';
  form.elements.title.value = a?.title ?? '';
  form.elements.body.value = a?.body ?? '';
  // Publishing state of an existing announcement is changed with its own button.
  form.elements.is_published.closest('label').hidden = Boolean(a);
  $('#announcement-dialog').showModal();
}

$('#add-announcement').addEventListener('click', () => openAnnouncementDialog());

$('#announcement-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  const form = e.target;
  const payload = { title: form.elements.title.value, body: form.elements.body.value };
  try {
    if (state.editingAnnouncementId) {
      await api('PATCH', `/admin/announcements/${state.editingAnnouncementId}`, payload);
    } else {
      await api('POST', '/admin/announcements', { ...payload, is_published: form.elements.is_published.checked });
    }
    $('#announcement-dialog').close();
    toast('Сохранено');
    await loadAnnouncements();
  } catch (err) {
    form.querySelector('.error').textContent = err.message;
  }
});

document.querySelectorAll('[data-close]').forEach((b) => b.addEventListener('click', () => b.closest('dialog').close()));

// ------------------------------------------------------------------ start

const saved = loadToken();
if (saved) startSession(saved).catch((err) => logout(err.status === 401 ? 'Сессия истекла, войдите снова' : err.message));
else showLogin();
