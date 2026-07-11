import { Router } from 'express';
import { JsonDB } from '../db';

interface SponsorData {
  sponsors: Array<{
    name: string;
    amount: number;
    time: string;
    message: string;
  }>;
}

const db = new JsonDB<SponsorData>('sponsors.json');

const router = Router();

router.get('/', (req, res) => {
  const data = db.read();
  res.json(data);
});

router.post('/', (req, res) => {
  try {
    const newData = req.body;
    db.write(newData);
    res.json({ success: true, message: '赞助数据已保存' });
  } catch (error) {
    res.status(500).json({ success: false, message: '保存失败: ' + error });
  }
});

export default router;
