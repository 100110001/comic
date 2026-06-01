import fs from 'fs';
import path from 'path';
import mysql from 'mysql2/promise';
import dotenv from 'dotenv';
import { progress, done } from '../utils/progress';
dotenv.config();

const SCAN_FILE = path.join(__dirname, '../../data/scan.json');

interface ImageFile { filename: string; path: string; width: number | null; height: number | null; }
interface Chapter   { name: string; path: string; images: ImageFile[]; }
interface Comic     { name: string; title: string; author: string | null; path: string; chapters: Chapter[]; }

async function seed() {
  const comics: Comic[] = JSON.parse(fs.readFileSync(SCAN_FILE, 'utf-8'));
  const total = comics.length;

  const conn = await mysql.createConnection({
    host:     process.env.DB_HOST     ?? 'localhost',
    port:     Number(process.env.DB_PORT ?? 3306),
    user:     process.env.DB_USER     ?? 'root',
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME     ?? 'comic',
    multipleStatements: true,
  });

  let comicCount = 0, chapterCount = 0, imageCount = 0;

  for (let idx = 0; idx < comics.length; idx++) {
    const comic = comics[idx]!;
    progress('导入', idx + 1, total, comic.title.slice(0, 35));

    const coverPath = comic.chapters[0]?.images[0]?.path ?? null;
    const [comicResult] = await conn.execute<mysql.ResultSetHeader>(
      'INSERT IGNORE INTO comics (title, author, cover_path) VALUES (?, ?, ?)',
      [comic.title, comic.author, coverPath]
    );

    let comicId = comicResult.insertId;
    if (comicId === 0) {
      const [rows] = await conn.execute<mysql.RowDataPacket[]>(
        'SELECT id FROM comics WHERE title = ?', [comic.title]
      );
      comicId = rows[0]!.id;
    } else {
      comicCount++;
    }

    for (let ci = 0; ci < comic.chapters.length; ci++) {
      const chapter = comic.chapters[ci]!;
      const [chapterResult] = await conn.execute<mysql.ResultSetHeader>(
        'INSERT IGNORE INTO chapters (comic_id, title, sort_order) VALUES (?, ?, ?)',
        [comicId, chapter.name, ci]
      );

      let chapterId = chapterResult.insertId;
      if (chapterId === 0) {
        const [rows] = await conn.execute<mysql.RowDataPacket[]>(
          'SELECT id FROM chapters WHERE comic_id = ? AND title = ?', [comicId, chapter.name]
        );
        chapterId = rows[0]!.id;
      } else {
        chapterCount++;
      }

      if (chapter.images.length === 0) continue;

      const imageValues = chapter.images.map((img, pi) =>
        [chapterId, img.filename, img.path, pi, img.width, img.height]
      );
      await conn.query(
        'INSERT IGNORE INTO images (chapter_id, filename, path, page_number, width, height) VALUES ?',
        [imageValues]
      );
      imageCount += chapter.images.length;
    }
  }

  await conn.end();
  done(`导入完成 — 漫画: ${comicCount}  章节: ${chapterCount}  图片: ${imageCount}`);
}

seed().catch(err => {
  console.error('导入失败:', err);
  process.exit(1);
});
