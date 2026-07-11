import { Router } from 'express';
import { JsonDB } from '../db';

interface ReleaseData {
  app: {
    version: string;
    buildNumber: number;
    changelog: string;
    url: {
      windows: string;
      linux: string;
      macos: string;
    };
    hash: {
      windows: string;
      linux: string;
      macos: string;
    };
  };
  core: {
    windows: {
      version: string;
      url: string;
      hash: string;
      filename: string;
    };
    linux: {
      version: string;
      url: string;
      hash: string;
      filename: string;
    };
    macos: {
      version: string;
      url: string;
      hash: string;
      filename: string;
    };
  };
  easytier: {
    windows: {
      version: string;
      url: string;
      hash: string;
    };
    linux: {
      version: string;
      url: string;
      hash: string;
    };
    macos: {
      version: string;
      url: string;
      hash: string;
    };
  };
}

const db = new JsonDB<ReleaseData>('releases.json');

const router = Router();

router.get('/', (req, res) => {
  const data = db.read();
  res.json(data);
});

router.post('/', (req, res) => {
  try {
    const newData = req.body;
    db.write(newData);
    res.json({ success: true, message: '版本数据已保存' });
  } catch (error) {
    res.status(500).json({ success: false, message: '保存失败: ' + error });
  }
});

export default router;
