import { Router } from 'express';
import type { Request, Response } from 'express';
import { pool } from '../db/pool';
import { ok, fail } from '../utils/response';

export const chaptersRouter = Router();

const COMIC_ROOT = 'E:\\comic';

function toUrl(filePath: string): string {
  return '/static/' + filePath.replace(COMIC_ROOT, '').replace(/\\/g, '/').replace(/^\//, '');
}

chaptersRouter.get('/:id/images', async (req: Request, res: Response) => {
  try {
    const id = parseInt(String(req.params.id));
    if (isNaN(id)) return fail(res, 'Invalid id');

    const [chapters] = await pool.query(
      'SELECT id, title FROM chapters WHERE id = ?', [id]
    ) as any;
    if (!chapters.length) return fail(res, 'Chapter not found', 1, 404);

    const [images] = await pool.query(
      'SELECT id, filename, path, page_number FROM images WHERE chapter_id = ? ORDER BY page_number',
      [id]
    ) as any;

    const data = images.map((img: any) => ({
      id:         img.id,
      filename:   img.filename,
      pageNumber: img.page_number,
      url:        toUrl(img.path),
    }));

    ok(res, data);
  } catch (err) {
    fail(res, 'Failed to fetch images', 1, 500);
  }
});
