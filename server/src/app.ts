import express from 'express';
import cors from 'cors';
import path from 'path';
import { createHash, timingSafeEqual } from 'crypto';
import { config } from './config';
import { validateCorePlatform, validateDocument } from './validation';
import presetRouter from './routes/preset';
import noticeRouter from './routes/notice';
import sponsorRouter from './routes/sponsor';
import releaseRouter from './routes/release';
import coreRouter from './routes/core';
import healthRouter from './routes/health';

export function createApp() {
  const app = express();
  app.use(cors());
  app.use(express.json({ limit: '1mb' }));
  app.use('/data', express.static(config.dataDir));
  app.use('/api', (req, res, next) => {
    if (['GET', 'HEAD', 'OPTIONS'].includes(req.method)) return next();
    const secret = process.env.ADMIN_TOKEN;
    if (!secret) {
      res.status(503).json({ success: false, message: '管理员写入功能未配置' });
      return;
    }
    const digest = (s: string) => createHash('sha256').update(s).digest();
    const supplied = req.get('Authorization')?.replace(/^Bearer /, '') ?? '';
    if (!timingSafeEqual(digest(supplied), digest(secret))) {
      res.status(401).json({ success: false, message: '管理密钥无效' });
      return;
    }
    const parts = req.path.split('/').filter(Boolean);
    const error = parts[0] === 'core' && parts.length === 2
      ? validateCorePlatform(req.body) : validateDocument(parts[0], req.body);
    if (error) {
      res.status(400).json({ success: false, message: error });
      return;
    }
    next();
  });
  app.use('/api/preset', presetRouter);
  app.use('/api/notices', noticeRouter);
  app.use('/api/sponsors', sponsorRouter);
  app.use('/api/releases', releaseRouter);
  app.use('/api/core', coreRouter);
  app.use('/api/health', healthRouter);
  app.use('/api', (_req, res) => res.status(404).json({ message: 'API 不存在' }));
  app.use(express.static(path.join(__dirname, '../public')));
  app.get('*', (_req, res) => res.sendFile(path.join(__dirname, '../public/index.html')));
  app.use((error: unknown, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
    const status = error && typeof error === 'object' && 'status' in error ? Number(error.status) : 500;
    console.error(error);
    res.status(status >= 400 && status < 600 ? status : 500).json({ success: false, message: '请求处理失败' });
  });
  return app;
}
