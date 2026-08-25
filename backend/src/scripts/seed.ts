import fs from "fs";
import path from "path";
import mysql from "mysql2/promise";
import dotenv from "dotenv";
import { progress, done } from "../utils/progress";
dotenv.config();

const SCAN_FILE = path.join(__dirname, "../../data/scan.json");

interface ImageFile {
  filename: string;
  path: string;
}
interface Chapter {
  name: string;
  path: string;
  images: ImageFile[];
}
interface Comic {
  name: string;
  title: string;
  author: string | null;
  path: string;
  chapters: Chapter[];
}

async function seed() {
  const comics: Comic[] = JSON.parse(fs.readFileSync(SCAN_FILE, "utf-8"));
  const total = comics.length;

  const conn = await mysql.createConnection({
    host: process.env.DB_HOST ?? "localhost",
    port: Number(process.env.DB_PORT ?? 3306),
    user: process.env.DB_USER ?? "root",
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME ?? "comic",
    multipleStatements: true,
  });

  let newComicCount = 0;
  let newChapterCount = 0;
  let newImageCount = 0;

  for (let idx = 0; idx < comics.length; idx++) {
    const comic = comics[idx]!;
    progress("导入", idx + 1, total, comic.title.slice(0, 35));

    const coverPath = comic.chapters[0]?.images[0]?.path ?? null;

    // comic：按 title+author 匹配，命中复用 id，未命中插入
    const comicId = await upsertComic(conn, comic.title, comic.author, coverPath);
    if (comicId.new) newComicCount++;

    // chapter：按 comic_id+title 匹配，未命中插入；全部处理完后整体覆写 sort_order
    const existingChapters = await getExistingChapters(conn, comicId.id);
    const chapterIds: number[] = [];

    for (let ci = 0; ci < comic.chapters.length; ci++) {
      const chapter = comic.chapters[ci]!;
      const existing = existingChapters.find((c) => c.title === chapter.name);
      let chapterId: number;

      if (existing) {
        chapterId = existing.id;
      } else {
        const [result] = await conn.execute<mysql.ResultSetHeader>(
          "INSERT INTO chapters (comic_id, title, sort_order) VALUES (?, ?, ?)",
          [comicId.id, chapter.name, ci],
        );
        chapterId = result.insertId;
        newChapterCount++;
      }
      chapterIds.push(chapterId);

      // image：按 chapter_id+filename 匹配，未命中插入；全部处理完后整体覆写 page_number
      const existingImages = await getExistingImages(conn, chapterId);
      for (let pi = 0; pi < chapter.images.length; pi++) {
        const img = chapter.images[pi]!;
        if (!existingImages.has(img.filename)) {
          await conn.execute(
            "INSERT INTO images (chapter_id, filename, path, page_number) VALUES (?, ?, ?, ?)",
            [chapterId, img.filename, img.path, pi],
          );
          newImageCount++;
        }
        await conn.execute(
          "UPDATE images SET page_number = ? WHERE chapter_id = ? AND filename = ?",
          [pi, chapterId, img.filename],
        );
      }
    }

    // 用扫描顺序整体覆写该漫画下所有章节的 sort_order（覆盖已存在章节的排序）
    for (let ci = 0; ci < chapterIds.length; ci++) {
      await conn.execute("UPDATE chapters SET sort_order = ? WHERE id = ?", [
        ci,
        chapterIds[ci],
      ]);
    }
  }

  // 磁盘上消失的漫画：只提示，不删除（R11）
  const [dbComics] = await conn.query<mysql.RowDataPacket[]>(
    "SELECT id, title, author FROM comics",
  );
  const scannedKeys = new Set(
    comics.map((c) => `${c.title}\u0000${c.author ?? ""}`),
  );
  let missingCount = 0;
  for (const row of dbComics) {
    const key = `${row.title}\u0000${row.author ?? ""}`;
    if (!scannedKeys.has(key)) {
      console.log(
        `\n[missing] 磁盘上未找到: ${row.title}${row.author ? ` (${row.author})` : ""}`,
      );
      missingCount++;
    }
  }

  await conn.end();
  done(
    `导入完成 — 新增漫画: ${newComicCount}  新增章节: ${newChapterCount}  新增图片: ${newImageCount}` +
      (missingCount > 0 ? `  磁盘缺失（未删除）: ${missingCount}` : ""),
  );
}

async function upsertComic(
  conn: mysql.Connection,
  title: string,
  author: string | null,
  coverPath: string | null,
): Promise<{ id: number; new: boolean }> {
  const [rows] = await conn.execute<mysql.RowDataPacket[]>(
    "SELECT id, cover_path, author FROM comics WHERE title = ?",
    [title],
  );
  const match = rows.find((r) => (r.author ?? null) === (author ?? null));
  if (match) {
    if (coverPath != null && match.cover_path !== coverPath) {
      await conn.execute("UPDATE comics SET cover_path = ? WHERE id = ?", [
        coverPath,
        match.id,
      ]);
    }
    return { id: match.id, new: false };
  }

  const [result] = await conn.execute<mysql.ResultSetHeader>(
    "INSERT INTO comics (title, author, cover_path) VALUES (?, ?, ?)",
    [title, author, coverPath],
  );
  return { id: result.insertId, new: true };
}

async function getExistingChapters(
  conn: mysql.Connection,
  comicId: number,
): Promise<Array<{ id: number; title: string }>> {
  const [rows] = await conn.execute<mysql.RowDataPacket[]>(
    "SELECT id, title FROM chapters WHERE comic_id = ?",
    [comicId],
  );
  return rows as Array<{ id: number; title: string }>;
}

async function getExistingImages(
  conn: mysql.Connection,
  chapterId: number,
): Promise<Set<string>> {
  const [rows] = await conn.execute<mysql.RowDataPacket[]>(
    "SELECT filename FROM images WHERE chapter_id = ?",
    [chapterId],
  );
  return new Set(rows.map((r) => r.filename));
}

seed().catch((err) => {
  console.error("导入失败:", err);
  process.exit(1);
});
