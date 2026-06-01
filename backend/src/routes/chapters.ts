import { Router } from 'express';
import type { Request, Response } from 'express';
import { imageSize } from 'image-size';
import { pool } from '../db/pool';
import { ok, fail } from '../utils/response';

export const chaptersRouter = Router();

const COMIC_ROOT = 'E:\\comic';

function toUrl(filePath: string): string {
  return '/static/' + filePath.replace(COMIC_ROOT, '').replace(/\\/g, '/').replace(/^\//, '');
}

async function fillDimensions(images: any[]) {
  const missing = images.filter(img => img.width == null);
  if (missing.length === 0) return;

  await Promise.all(
    missing.map(async img => {
      try {
        const dim = imageSize(img.path);
        img.width  = dim.width  ?? null;
        img.height = dim.height ?? null;
        await pool.execute(
          'UPDATE images SET width = ?, height = ? WHERE id = ?',
          [img.width, img.height, img.id]
        );
      } catch {}
    })
  );
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
      'SELECT id, filename, path, page_number, width, height FROM images WHERE chapter_id = ? ORDER BY page_number',
      [id]
    ) as any;

    await fillDimensions(images);

    const data = images.map((img: any) => ({
      id:         img.id,
      filename:   img.filename,
      pageNumber: img.page_number,
      url:        toUrl(img.path),
      width:      img.width,
      height:     img.height,
    }));

    ok(res, data);
  } catch (err) {
    fail(res, 'Failed to fetch images', 1, 500);
  }
});
