import { Router, Request, Response } from 'express';
import { JsonDB } from '../db';

interface PlatformCoreInfo {
  version: string;
  url: string;
  hash: string;
  filename?: string;
}

interface CoreData {
  core: {
    windows: PlatformCoreInfo;
    linux: PlatformCoreInfo;
    macos: PlatformCoreInfo;
  };
  easytier: {
    windows: PlatformCoreInfo;
    linux: PlatformCoreInfo;
    macos: PlatformCoreInfo;
  };
}

const db = new JsonDB<CoreData>('releases.json');

const router = Router();

// GET /api/core - 获取所有平台核心信息
router.get('/', (req: Request, res: Response) => {
  const data = db.read();
  res.json({
    core: data.core,
    easytier: data.easytier
  });
});

// GET /api/core/:platform - 获取指定平台核心信息
router.get('/:platform', (req: Request, res: Response) => {
  const platform = req.params.platform.toLowerCase();
  const validPlatforms = ['windows', 'linux', 'macos'];

  if (!validPlatforms.includes(platform)) {
    return res.status(400).json({
      success: false,
      message: '无效的平台，支持: windows, linux, macos'
    });
  }

  const data = db.read();
  const coreInfo = (data.core as any)[platform];
  const easytierInfo = (data.easytier as any)[platform];

  res.json({
    platform,
    core: coreInfo,
    easytier: easytierInfo
  });
});

// POST /api/core - 更新核心信息
router.post('/', (req: Request, res: Response) => {
  try {
    const { core, easytier } = req.body;
    const data = db.read();

    if (core) {
      // 验证并更新 core 数据
      for (const platform of ['windows', 'linux', 'macos']) {
        if (core[platform]) {
          const platformData = core[platform];
          if (!platformData.version || !platformData.url || !platformData.hash) {
            return res.status(400).json({
              success: false,
              message: `${platform} 平台 core 数据不完整，需要 version, url, hash`
            });
          }
          (data.core as any)[platform] = platformData;
        }
      }
    }

    if (easytier) {
      // 验证并更新 easytier 数据
      for (const platform of ['windows', 'linux', 'macos']) {
        if (easytier[platform]) {
          const platformData = easytier[platform];
          if (!platformData.version || !platformData.url || !platformData.hash) {
            return res.status(400).json({
              success: false,
              message: `${platform} 平台 easytier 数据不完整，需要 version, url, hash`
            });
          }
          (data.easytier as any)[platform] = platformData;
        }
      }
    }

    db.write(data);
    res.json({ success: true, message: '核心信息已更新' });
  } catch (error) {
    res.status(500).json({ success: false, message: '更新失败: ' + error });
  }
});

// POST /api/core/:platform - 更新指定平台核心信息
router.post('/:platform', (req: Request, res: Response) => {
  const platform = req.params.platform.toLowerCase();
  const validPlatforms = ['windows', 'linux', 'macos'];

  if (!validPlatforms.includes(platform)) {
    return res.status(400).json({
      success: false,
      message: '无效的平台，支持: windows, linux, macos'
    });
  }

  try {
    const { core, easytier } = req.body;
    const data = db.read();

    if (core) {
      if (!core.version || !core.url || !core.hash) {
        return res.status(400).json({
          success: false,
          message: 'core 数据不完整，需要 version, url, hash'
        });
      }
      (data.core as any)[platform] = core;
    }

    if (easytier) {
      if (!easytier.version || !easytier.url || !easytier.hash) {
        return res.status(400).json({
          success: false,
          message: 'easytier 数据不完整，需要 version, url, hash'
        });
      }
      (data.easytier as any)[platform] = easytier;
    }

    db.write(data);
    res.json({ success: true, message: `${platform} 平台核心信息已更新` });
  } catch (error) {
    res.status(500).json({ success: false, message: '更新失败: ' + error });
  }
});

export default router;
