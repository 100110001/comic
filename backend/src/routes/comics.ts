import { Router } from 'express';
import type { Request, Response } from 'express';
import { pool } from '../db/pool';

export const comicsRouter = Router();

comicsRouter.get('/', async (_req: Request, res: Response) => {
  const [rows] = await pool.query(
    'SELECT id, title, author, cover_path, status, created_at FROM comics ORDER BY title'
  );
  res.json(rows);
});
