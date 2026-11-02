/**
 * Fake SmartNation portal: a tiny HTTP server with the same paths and response
 * formats as the real one (Laravel: CSRF, cookie session, ?withFilters=true).
 * Any 12-digit IIN works; its password is "pw-<IIN>".
 */
import http from 'node:http';

export const account = (login) => (/^\d{12}$/.test(String(login))
  ? { password: `pw-${login}`, name: `Студент ${String(login).slice(-4)}`, studentId: Number(String(login).slice(-6)) }
  : null);

export function startFakeSmartNation({ group = 'ПО2406' } = {}) {
  const sessions = new Map(); // sid -> login

  const server = http.createServer((req, res) => {
    const url = new URL(req.url, 'http://x');
    const p = url.pathname.replace(/^\/ru\/[a-z]+\//, '');
    const sid = (req.headers.cookie || '').match(/laravel_session=(\w+)/)?.[1];
    const login = sessions.get(sid);
    const json = (status, body) => {
      res.writeHead(status, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(body));
    };

    if (p === 'login' && req.method === 'GET') {
      const newSid = Math.random().toString(36).slice(2);
      res.writeHead(200, {
        'Content-Type': 'text/html',
        'Set-Cookie': ['XSRF-TOKEN=tok%3D; path=/', `laravel_session=${newSid}; path=/; HttpOnly`],
      });
      res.end('<html><head><meta name="csrf-token" content="csrf123"></head></html>');
      return;
    }
    if (p === 'login' && req.method === 'POST') {
      let body = '';
      req.on('data', (c) => { body += c; });
      req.on('end', () => {
        const data = JSON.parse(body || '{}');
        const acc = account(data.iin || data.login);
        if (req.headers['x-csrf-token'] !== 'csrf123') return json(419, { message: 'CSRF' });
        if (!acc || acc.password !== data.password) return json(422, { message: 'Неверные данные' });
        sessions.set(sid, data.iin || data.login);
        res.writeHead(204);
        return res.end();
      });
      return;
    }

    if (!login) {
      res.writeHead(302, { Location: '/ru/tko/login' });
      res.end();
      return;
    }
    const acc = account(login);

    if (p === 'control/journals') {
      json(200, {
        data: [{ id: 11, name: '3 курс ПМ07-Разработка мобильных приложений(ПО)', type: 'Теоретическое обучение', group, educators: 'Синтиков Е.К.' }],
        meta: { last_page: 1 },
      });
      return;
    }
    if (p === 'control/summary') {
      json(200, { data: [{ group, course: 3, qualification: 'Разработчик ПО', educator: 'Куратор' }] });
      return;
    }
    if (p === 'control/journals/11/contingent') {
      json(200, { students: [{ id: acc.studentId, fullName: acc.name, isCurrent: 1 }] });
      return;
    }
    if (p === 'control/journals/11/refs') {
      json(200, { yearMonths: [{ id: '10/2026' }] });
      return;
    }
    if (p === 'control/journals/11/load-table') {
      json(200, {
        days: [
          { label: '13.10', theme: 'ПР 1', points: { [acc.studentId]: { point: 90, label: '90', absented: false }, 999: { point: 10, label: '10' } } },
          { label: '16.10', theme: 'ПР 2', points: { [acc.studentId]: { point: null, label: 'Н', absented: true } } },
          { label: '20.10', theme: 'ПР 3', points: { [acc.studentId]: { point: 100, label: '100', absented: false } } },
        ],
      });
      return;
    }
    if (p === 'control/assigned-homework/disciplines-list') {
      res.writeHead(200, { 'Content-Type': 'text/html' });
      res.end('<a href="?discipline=77">Посмотреть</a>');
      return;
    }
    if (p === 'control/assigned-homeworks') {
      const closed = url.searchParams.get('closed') === '1';
      json(200, {
        data: closed
          ? [{ id: 2, name: 'Практическая 1', journal: { name: '3курс ПМ07-Разработка мобильных приложений' }, created_at: '01.10.2026 10:00', expired_at: '05.10.2026 23:00', date_point: '01.10.2026', contingent: { status: 'Проверено', result: 95 } }]
          : [{ id: 3, name: 'Практическая 5', journal: { name: '3курс ПМ07-Разработка мобильных приложений' }, created_at: '29.10.2026 10:00', expired_at: '30.12.2099 23:00', date_point: '29.10.2026', contingent: { status: 'В ожидании', result: '-' } }],
        meta: { last_page: 1 },
      });
      return;
    }
    json(404, { message: 'not found' });
  });

  return new Promise((resolve) => {
    server.listen(0, '127.0.0.1', () => resolve({
      server,
      baseUrl: `http://127.0.0.1:${server.address().port}`,
      close() {
        server.closeAllConnections();
        server.close();
      },
    }));
  });
}
