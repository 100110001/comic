import mysql from "mysql2/promise";
import dotenv from "dotenv";
import { progress, done } from "../utils/progress";
import { readImageDimensions } from "../utils/image-metadata";
import type { Comic } from "./scan";
dotenv.config();

const BATCH_SIZE = 200;
type Value = string | number | null;
interface ImageRow extends mysql.RowDataPacket {
  id: number;
  chapter_id: number;
  filename: string;
  path: string;
  page_number: number;
  width: number | null;
  height: number | null;
}
interface ChangedRow {
  id: number;
  values: Value[];
}

export async function seed(comics: Comic[]) {
  const total = comics.length;
  const conn = await mysql.createConnection({
    host: process.env.DB_HOST ?? "localhost",
    port: Number(process.env.DB_PORT ?? 3306),
    user: process.env.DB_USER ?? "root",
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME ?? "comic",
    multipleStatements: true,
  });

  try {
    let newComicCount = 0;
    let newChapterCount = 0;
    let newImageCount = 0;

    for (let idx = 0; idx < comics.length; idx++) {
      const comic = comics[idx]!;
      progress("导入", idx + 1, total, comic.title.slice(0, 35));
      const coverPath = comic.chapters[0]?.images[0]?.path ?? null;
      const comicId = await upsertComic(
        conn,
        comic.title,
        comic.author,
        coverPath,
      );
      if (comicId.new) newComicCount++;

      const existingChapters = await getExistingChapters(conn, comicId.id);
      const imagesByChapter = await getExistingImages(conn, comicId.id);
      const chapterChanges = new Map<number, number>();
      const visitedChapters = new Set<number>();

      for (let ci = 0; ci < comic.chapters.length; ci++) {
        const chapter = comic.chapters[ci]!;
        const existing = existingChapters.find((c) => c.title === chapter.name);
        let chapterId: number;
        if (existing) {
          chapterId = existing.id;
          if (existing.sort_order !== ci) chapterChanges.set(chapterId, ci);
          else chapterChanges.delete(chapterId);
        } else {
          const [result] = await conn.execute<mysql.ResultSetHeader>(
            "INSERT INTO chapters (comic_id, title, sort_order) VALUES (?, ?, ?)",
            [comicId.id, chapter.name, ci],
          );
          chapterId = result.insertId;
          newChapterCount++;
        }

        // 根图片与同名子目录可能映射到同一章节，后一次必须看到前一次写入。
        const source = visitedChapters.has(chapterId)
          ? await getExistingImages(conn, comicId.id, chapterId)
          : imagesByChapter;
        visitedChapters.add(chapterId);
        const existingImages = source.get(chapterId);
        let inserted: Value[][] = [];
        let changed: ChangedRow[] = [];

        for (let pi = 0; pi < chapter.images.length; pi++) {
          const img = chapter.images[pi]!;
          // 保持原有逐张串行尺寸探测及失败空值语义。
          const dimensions = await readImageDimensions(img.path).catch(
            () => null,
          );
          const width = dimensions?.width ?? null;
          const height = dimensions?.height ?? null;
          const current = existingImages?.get(img.filename);
          if (!current) {
            inserted.push([
              chapterId,
              img.filename,
              img.path,
              pi,
              width,
              height,
            ]);
            newImageCount++;
            if (inserted.length === BATCH_SIZE) {
              await insertImages(conn, inserted);
              inserted = [];
            }
          } else if (
            current.path !== img.path ||
            current.page_number !== pi ||
            current.width !== width ||
            current.height !== height
          ) {
            changed.push({
              id: current.id,
              values: [img.path, pi, width, height],
            });
            if (changed.length === BATCH_SIZE) {
              await updateRows(
                conn,
                "images",
                ["path", "page_number", "width", "height"],
                changed,
              );
              changed = [];
            }
          }
        }
        await insertImages(conn, inserted);
        await updateRows(
          conn,
          "images",
          ["path", "page_number", "width", "height"],
          changed,
        );
      }

      await updateRows(
        conn,
        "chapters",
        ["sort_order"],
        [...chapterChanges].map(([id, order]) => ({ id, values: [order] })),
      );
    }

    // 磁盘上消失的漫画只提示，不删除。
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

    done(
      `导入完成 — 新增漫画: ${newComicCount}  新增章节: ${newChapterCount}  新增图片: ${newImageCount}` +
        (missingCount > 0 ? `  磁盘缺失（未删除）: ${missingCount}` : ""),
    );
  } finally {
    await conn.end();
  }
}

async function insertImages(conn: mysql.Connection, rows: Value[][]) {
  if (!rows.length) return;
  await conn.query(
    `INSERT INTO images (chapter_id, filename, path, page_number, width, height) VALUES ${rows.map(() => "(?, ?, ?, ?, ?, ?)").join(", ")}`,
    rows.flat(),
  );
}

// 表和列均由本模块的固定调用提供，数据全部通过参数传递。
// query 避免为每种批次长度保留一份服务端预编译语句。
async function updateRows(
  conn: mysql.Connection,
  table: "images" | "chapters",
  columns: string[],
  rows: ChangedRow[],
) {
  for (let offset = 0; offset < rows.length; offset += BATCH_SIZE) {
    const batch = rows.slice(offset, offset + BATCH_SIZE);
    const parameters: Value[] = [];
    const assignments = columns.map((column, index) => {
      const cases = batch.map((row) => {
        parameters.push(row.id, row.values[index]!);
        return "WHEN ? THEN ?";
      });
      return `${column} = CASE id ${cases.join(" ")} ELSE ${column} END`;
    });
    parameters.push(...batch.map((row) => row.id));
    await conn.query(
      `UPDATE ${table} SET ${assignments.join(", ")} WHERE id IN (${batch.map(() => "?").join(", ")})`,
      parameters,
    );
  }
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
): Promise<Array<{ id: number; title: string; sort_order: number }>> {
  const [rows] = await conn.execute<mysql.RowDataPacket[]>(
    "SELECT id, title, sort_order FROM chapters WHERE comic_id = ?",
    [comicId],
  );
  return rows as Array<{ id: number; title: string; sort_order: number }>;
}

async function getExistingImages(
  conn: mysql.Connection,
  comicId: number,
  chapterId?: number,
): Promise<Map<number, Map<string, ImageRow>>> {
  const [rows] = await conn.query<ImageRow[]>(
    "SELECT images.id, images.chapter_id, images.filename, images.path, images.page_number, images.width, images.height FROM images INNER JOIN chapters ON chapters.id = images.chapter_id WHERE chapters.comic_id = ?" +
      (chapterId === undefined ? "" : " AND images.chapter_id = ?"),
    chapterId === undefined ? [comicId] : [comicId, chapterId],
  );
  const grouped = new Map<number, Map<string, ImageRow>>();
  for (const row of rows) {
    let chapter = grouped.get(row.chapter_id);
    if (!chapter) {
      chapter = new Map();
      grouped.set(row.chapter_id, chapter);
    }
    chapter.set(row.filename, row);
  }
  return grouped;
}
