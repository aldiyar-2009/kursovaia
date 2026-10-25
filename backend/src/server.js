import http from 'node:http';
import os from 'node:os';
import qrcode from 'qrcode-terminal';
import { createApp } from './app.js';
import { closeDb, db } from './config/db.js';
import { env } from './config/env.js';

async function main() {
  // Apply pending migrations automatically so `npm start` just works.
  const [, pending] = await db.migrate.latest();
  if (pending.length) console.log(`[db] applied migrations: ${pending.join(', ')}`);

  const app = createApp();
  const server = http.createServer(app);

  server.listen(env.port, env.host, () => {
    const interfaces = Object.entries(os.networkInterfaces());
    const lanIps = [];
    for (const [name, addrs] of interfaces) {
      for (const a of addrs || []) {
        if (a && a.family === 'IPv4' && !a.internal) {
          lanIps.push({ name, ip: a.address, url: `http://${a.address}:${env.port}` });
        }
      }
    }

    console.log(`\n=============================================================`);
    console.log(`  🎓 StudyPlan Backend & Mobile App Server Ready`);
    console.log(`=============================================================`);
    console.log(`  ➜ Локально (на ПК):          http://localhost:${env.port}/`);

    const primary = lanIps.find((item) => {
      const n = item.name.toLowerCase();
      return !n.includes('vethernet') && !n.includes('radmin') && !item.ip.startsWith('169.254');
    }) || lanIps[0];

    for (const item of lanIps) {
      const isPrimary = item === primary ? ' (Основной)' : '';
      console.log(`  📱 На смартфоне [${item.name}]${isPrimary}: ${item.url}/`);
    }
    console.log(`=============================================================`);

    if (primary) {
      console.log(`\n  📸 Отсканируйте QR-код камерой смартфона для входа:`);
      qrcode.generate(`${primary.url}/`, { small: true });
    }
    console.log(`  💡 Примечание: смартфон и ПК должны быть в одной Wi-Fi сети.\n`);
  });

  const shutdown = async (signal) => {
    console.log(`\n[server] ${signal} received, shutting down...`);
    server.close();
    await closeDb();
    process.exit(0);
  };
  process.on('SIGINT', () => shutdown('SIGINT'));
  process.on('SIGTERM', () => shutdown('SIGTERM'));
}

main().catch(async (err) => {
  console.error('[server] failed to start:', err);
  if (env.db.client === 'pg') {
    console.error('  Hint: check PostgreSQL is running and DATABASE_URL / PG_* in backend/.env are correct,');
    console.error('        or set DB_CLIENT=sqlite to use the zero-install local database.');
  }
  await closeDb().catch(() => {});
  process.exit(1);
});
