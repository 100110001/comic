import fs from 'fs';
import path from 'path';
import mysql from 'mysql2/promise';
import dotenv from 'dotenv';
dotenv.config();

const SCAN_FILE = path.join(__dirname, '../../data/scan.json');

interface ImageFile { filename: string; path: string; }
interface Chapter   { name: string; path: string; images: ImageFile[]; }
interface Comic     { name: string; title: string; author: string | null; path: string; chapters: Chapter[]; }

async function seed() {
  const comics: Comic[] = JSON.parse(fs.readFileSync(SCAN_FILE, 'utf-8'));

  const conn = await mysql.createConnection({
    host:     process.env.DB_HOST     ?? 'localhost',
    port:     Number(process.env.DB_PORT ?? 3306),
    user:     process.env.DB_USER     ?? 'root',
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME     ?? 'comic',
    multipleStatements: true,
  });

  let comicCount = 0, chapterCount = 0, imageCount = 0;

  for (const comic of comics) {
    const [comicResult] = await conn.execute<mysql.ResultSetHeader>(
      'INSERT IGNORE INTO comics (title, author) VALUES (?, ?)',
      [comic.title, comic.author]
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

      const imageValues = chapter.images.map((img, pi) => [chapterId, img.filename, img.path, pi]);
      await conn.query(
        'INSERT IGNORE INTO images (chapter_id, filename, path, page_number) VALUES ?',
        [imageValues]
      );
      imageCount += chapter.images.length;
    }
  }

  await conn.end();
  console.log(`导入完成 — 漫画: ${comicCount}  章节: ${chapterCount}  图片: ${imageCount}`);
}

seed().catch(err => {
  console.error('导入失败:', err);
  process.exit(1);
});
