import './setup.js';
import assert from 'node:assert/strict';
import http from 'node:http';
import { after, before, describe, test } from 'node:test';
import { io as connect } from 'socket.io-client';
import { attachSocketServer } from '../src/realtime/socket.js';
import { app, authed, db, registerUser, request, resetDb, uuid } from './helpers.js';

let server;
let baseUrl;
let ioServer;
const clients = [];

before(async () => {
  await resetDb();
  server = http.createServer(app);
  ioServer = attachSocketServer(server);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

after(async () => {
  for (const c of clients) c.close();
  ioServer.close();
  await new Promise((resolve) => server.close(resolve));
  await db.destroy();
});

const open = (token) => new Promise((resolve, reject) => {
  const socket = connect(baseUrl, { auth: { token }, transports: ['websocket'], reconnection: false });
  clients.push(socket);
  socket.on('connect', () => resolve(socket));
  socket.on('connect_error', (err) => reject(err));
});

const once = (socket, event, ms = 3000) => new Promise((resolve, reject) => {
  const timer = setTimeout(() => reject(new Error(`timeout waiting for ${event}`)), ms);
  socket.once(event, (payload) => { clearTimeout(timer); resolve(payload); });
});

describe('socket.io group chat', () => {
  test('rejects connections without a valid token', async () => {
    await assert.rejects(open('bad-token'), /UNAUTHORIZED/);
  });

  test('message from one member is delivered to the group in realtime and persisted', async () => {
    const headman = await registerUser('Староста');
    const g = await authed(headman.token).post('/api/groups').send({ title: 'RT-1' });
    const student = await registerUser('Студент', { invite_code: g.body.group.invite_code });

    const outsider = await registerUser('Чужой');
    const outsiderSocket = await open(outsider.token);
    let leaked = false;
    outsiderSocket.on('chat:message', () => { leaked = true; });

    const hs = await open(headman.token);
    const ss = await open(student.token);

    const incoming = once(hs, 'chat:message');
    const message = { id: uuid(), message_type: 'text', content: 'Привет из сокета', created_at: Date.now() };
    const ack = await ss.timeout(3000).emitWithAck('chat:send', message);
    assert.equal(ack.ok, true);
    assert.equal(ack.message.sender_name, 'Студент');

    const received = await incoming;
    assert.equal(received.id, message.id);
    assert.equal(received.content, 'Привет из сокета');

    const history = await authed(headman.token).get('/api/chat/messages');
    assert.ok(history.body.messages.some((m) => m.id === message.id));
    await new Promise((r) => setTimeout(r, 100));
    assert.equal(leaked, false, 'other groups must not receive the message');
  });

  test('ack reports validation errors (student cannot post schedule_update)', async () => {
    const headman = await registerUser('H');
    const g = await authed(headman.token).post('/api/groups').send({ title: 'RT-2' });
    const student = await registerUser('S', { invite_code: g.body.group.invite_code });
    const ss = await open(student.token);
    const ack = await ss.timeout(3000).emitWithAck('chat:send', { id: uuid(), message_type: 'schedule_update', content: 'fake' });
    assert.equal(ack.ok, false);
    assert.match(ack.error, /headman/i);
  });

  test('headman can pin messages, clients receive chat:updated', async () => {
    const headman = await registerUser('H3');
    await authed(headman.token).post('/api/groups').send({ title: 'RT-3' });
    const hs = await open(headman.token);
    const sent = await authed(headman.token).post('/api/chat/messages').send({ id: uuid(), content: 'Важно!' });
    assert.equal(sent.status, 201);
    const updated = once(hs, 'chat:updated');
    const pin = await authed(headman.token).patch(`/api/chat/messages/${sent.body.message.id}/pin`).send({ pinned: true });
    assert.equal(pin.body.message.is_pinned, true);
    assert.equal((await updated).id, sent.body.message.id);
  });

  test('file upload + authorized download', async () => {
    const user = await registerUser('Uploader');
    await authed(user.token).post('/api/groups').send({ title: 'RT-4' });
    const up = await authed(user.token).post('/api/chat/upload').attach('file', Buffer.from('%PDF-1.4 demo'), 'методичка.pdf');
    assert.equal(up.status, 201);
    assert.equal(up.body.file_name, 'методичка.pdf');
    const down = await authed(user.token).get(up.body.url);
    assert.equal(down.status, 200);
    assert.equal((await request(app).get(up.body.url)).status, 401);
    assert.equal((await authed(user.token).get('/api/files/..%2F..%2F.env')).status, 404);
  });
});
