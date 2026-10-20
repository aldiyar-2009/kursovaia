import cors from 'cors';
import express from 'express';
import helmet from 'helmet';
import morgan from 'morgan';
import { env } from './config/env.js';
import { errorHandler, notFoundHandler } from './middleware/error.js';
import { router } from './routes/index.js';

import fs from 'fs';
import path from 'path';

export function createApp() {
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

  const candidate1 = path.resolve('..', 'mobile', 'build', 'web');
  const candidate2 = path.resolve('mobile', 'build', 'web');
  const webDist = fs.existsSync(candidate1) ? candidate1 : (fs.existsSync(candidate2) ? candidate2 : null);
  if (webDist) {
    app.use(express.static(webDist));
    app.get('/', (_req, res) => res.sendFile(path.join(webDist, 'index.html')));
  } else {
    app.get('/', (_req, res) => res.json({ name: 'StudyPlan API', docs: '/api/health' }));
  }

  app.use(notFoundHandler);
  app.use(errorHandler);
  return app;
}
