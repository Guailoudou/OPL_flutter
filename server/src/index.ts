import express from 'express';
import cors from 'cors';
import path from 'path';
import { config } from './config';
import presetRouter from './routes/preset';
import noticeRouter from './routes/notice';
import sponsorRouter from './routes/sponsor';
import releaseRouter from './routes/release';
import coreRouter from './routes/core';
import healthRouter from './routes/health';

const app = express();

app.use(cors());
app.use(express.json());

// API路由
app.use('/api/preset', presetRouter);
app.use('/api/notices', noticeRouter);
app.use('/api/sponsors', sponsorRouter);
app.use('/api/releases', releaseRouter);
app.use('/api/core', coreRouter);
app.use('/api/health', healthRouter);

// 静态文件服务
app.use(express.static(path.join(__dirname, '../public')));

// Vue SPA 路由支持 - 所有非 API 请求都返回 index.html
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, '../public/index.html'));
});

app.listen(config.port, () => {
  console.log(`OPL Server running on http://localhost:${config.port}`);
  console.log(`Admin panel: http://localhost:${config.port}/admin`);
});
