import { Router } from 'express';
import type { Request, Response } from 'express';
import { comicsRouter } from './comics';

export const router = Router();

router.get('/health', (_req: Request, res: Response) => {
  res.json({ status: 'ok' });
});

router.use('/comics', comicsRouter);
