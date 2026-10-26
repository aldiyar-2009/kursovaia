import fs from 'node:fs';
import path from 'node:path';
import cors from 'cors';
import express from 'express';
import helmet from 'helmet';
import morgan from 'morgan';
import { env } from './config/env.js';
import { errorHandler, notFoundHandler } from './middleware/error.js';
import { router } from './routes/index.js';
import { openAppPage, requestOrigin } from './utils/open-app.js';

/** Flutter web build (`flutter build web`) next to the backend, if present. */
function findWebDist() {
  const candidates = [path.resolve('..', 'mobile', 'build', 'web'), path.resolve('mobile', 'build', 'web')];
  return candidates.find((p) => fs.existsSync(path.join(p, 'index.html'))) ?? null;
}

/**
 * @param {{ webDist?: string|null }} [options] `webDist` overrides web build discovery (tests).
 */
export function createApp({ webDist = findWebDist() } = {}) {
  const app = express();
  app.disable('x-powered-by');
  app.use(helmet({
    crossOriginResourcePolicy: { policy: 'cross-origin' },
    contentSecurityPolicy: false,
  }));
  app.use(cors({ origin: env.corsOrigins.includes('*') ? true : env.corsOrigins }));
  app.use(express.json({ limit: '5mb' }));
  if (!env.isTest) app.use(morgan('dev'));

  app.use('/api', router);

  // Target of the startup QR code: Android opens the installed app (which picks up
  // this server's address), other devices get the web version.
  app.get('/open', (req, res) => {
    const origin = requestOrigin(req);
    if (!origin || !/android/i.test(req.get('user-agent') ?? '')) return res.redirect('/');
    res.type('html').send(openAppPage(origin));
  });

  if (webDist) {
    // `root` keeps send's dotfile check on the requested file only, not on the build directory path.
    const sendIndex = (_req, res) => res.sendFile('index.html', { root: webDist });
    app.use(express.static(webDist));
    app.get('/', sendIndex);
    // Invite links `<server>/join/ABC123`: the SPA reads the code from the URL.
    app.get('/join/:code', sendIndex);
  } else {
    app.get('/', (_req, res) => res.json({ name: 'StudyPlan API', docs: '/api/health' }));
  }

  app.use(notFoundHandler);
  app.use(errorHandler);
  return app;
}
