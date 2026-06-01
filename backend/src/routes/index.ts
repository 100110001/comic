import { Router } from 'express';
import type { Request, Response } from 'express';
import { comicsRouter } from './comics';
import { chaptersRouter } from './chapters';
import { ok } from '../utils/response';

export const router = Router();

router.get('/health', (_req: Request, res: Response) => {
  ok(res, { status: 'ok' });
});

router.use('/comics', comicsRouter);
router.use('/chapters', chaptersRouter);
