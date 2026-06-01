import { Router } from "express";
import type { Request, Response } from "express";
import { pool } from "../db/pool";
import { ok, fail } from "../utils/response";

export const comicsRouter = Router();

comicsRouter.get("/", async (req: Request, res: Response) => {
  try {
    const pageOffset = Math.max(1, parseInt(String(req.query.pageOffset ?? 1)));
    const pageSize = Math.min(
      100,
      Math.max(1, parseInt(String(req.query.pageSize ?? 20))),
    );
    const offset = (pageOffset - 1) * pageSize;
    const keyword = String(req.query.keyword ?? "").trim();
    const like = `%${keyword}%`;

    const countSql = keyword
      ? "SELECT COUNT(*) AS total FROM comics WHERE title LIKE ? OR author LIKE ?"
      : "SELECT COUNT(*) AS total FROM comics";
    const countParams = keyword ? [like, like] : [];

    const listSql = keyword
      ? `SELECT id, title, author, cover_path, created_at FROM comics WHERE title LIKE ? OR author LIKE ? ORDER BY title LIMIT ${pageSize} OFFSET ${offset}`
      : `SELECT id, title, author, cover_path, created_at FROM comics ORDER BY title LIMIT ${pageSize} OFFSET ${offset}`;
    const listParams = keyword ? [like, like] : [];

    const [countRows] = (await pool.execute(countSql, countParams)) as any;
    const total = countRows[0].total as number;
    const [rows] = await pool.execute(listSql, listParams);

    ok(res, rows, { pageOffset, pageSize, total });
  } catch (err) {
    fail(res, "Failed to fetch comics", 1, 500);
  }
});

comicsRouter.get("/:id", async (req: Request, res: Response) => {
  try {
    const id = parseInt(String(req.params.id));
    if (isNaN(id)) return fail(res, "Invalid id");

    const [comics] = (await pool.query(
      "SELECT id, title, author, cover_path, created_at FROM comics WHERE id = ?",
      [id],
    )) as any;
    if (!comics.length) return fail(res, "Comic not found", 1, 404);

    const [chapters] = (await pool.query(
      "SELECT id, title, sort_order FROM chapters WHERE comic_id = ? ORDER BY sort_order",
      [id],
    )) as any;

    ok(res, { ...comics[0], chapters });
  } catch (err) {
    fail(res, "Failed to fetch comic", 1, 500);
  }
});
