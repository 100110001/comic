import { Router } from "express";
import type { Request, Response } from "express";
import fs from "fs";
import path from "path";
import { db } from "../db/knex";
import { ok, fail } from "../utils/response";
import { config } from "../config";

const COMIC_ROOT = config.comicRoot;

function getComicFolder(coverPath: string): string {
  const rel = coverPath.replace(COMIC_ROOT + "\\", "");
  return path.join(COMIC_ROOT, rel.split("\\")[0]!);
}

function comicQuery() {
  return db("comics")
    .select(
      "comics.id",
      "comics.title",
      "comics.author",
      "comics.cover_path",
      "comics.created_at",
      db.raw("COUNT(DISTINCT chapters.id) as chapter_count"),
      db.raw("COUNT(DISTINCT images.id) as image_count"),
    )
    .leftJoin("chapters", "comics.id", "chapters.comic_id")
    .leftJoin("images", "chapters.id", "images.chapter_id")
    .groupBy("comics.id");
}

export const comicsRouter = Router();

// 列表（分页 + 搜索）
comicsRouter.get("/", async (req: Request, res: Response) => {
  try {
    const pageOffset = Math.max(1, parseInt(String(req.query.pageOffset ?? 1)));
    const pageSize = Math.min(
      100,
      Math.max(1, parseInt(String(req.query.pageSize ?? 20))),
    );
    const keyword = String(req.query.keyword ?? "").trim();

    let query = comicQuery();
    if (keyword) {
      query = query
        .where("comics.title", "like", `%${keyword}%`)
        .orWhere("comics.author", "like", `%${keyword}%`);
    }

    const total = await query
      .clone()
      .clearSelect()
      .count("* as total")
      .first()
      .then((r) => Number((r as any).total));
    const rows = await query
      .orderBy("comics.title")
      .limit(pageSize)
      .offset((pageOffset - 1) * pageSize);

    ok(res, rows, { pageOffset, pageSize, total });
  } catch (err) {
    fail(res, "Failed to fetch comics", 1, 500);
  }
});

// 随机（必须在 /:id 前注册）
comicsRouter.get("/random", async (req: Request, res: Response) => {
  try {
    const size = Math.min(
      100,
      Math.max(1, parseInt(String(req.query.pageSize ?? 30))),
    );
    res.setHeader("Cache-Control", "no-store");
    const rows = await comicQuery().orderByRaw("RAND()").limit(size);
    ok(res, rows, { pageSize: size, total: (rows as any[]).length });
  } catch (err) {
    fail(res, "Failed to fetch random comics", 1, 500);
  }
});

// 详情
comicsRouter.get("/:id", async (req: Request, res: Response) => {
  try {
    const id = parseInt(String(req.params.id));
    if (isNaN(id)) return fail(res, "Invalid id");

    const comic = await comicQuery().where("comics.id", id).first();
    if (!comic) return fail(res, "Comic not found", 1, 404);

    const chapters = await db("chapters")
      .select("id", "title", "sort_order")
      .where({ comic_id: id })
      .orderBy("sort_order");

    ok(res, { ...comic, chapters });
  } catch (err) {
    fail(res, "Failed to fetch comic", 1, 500);
  }
});

// 删除
comicsRouter.delete("/:id", async (req: Request, res: Response) => {
  try {
    const id = parseInt(String(req.params.id));
    if (isNaN(id)) return fail(res, "Invalid id");

    const comic = await db("comics").where({ id }).first();
    if (!comic) return fail(res, "Comic not found", 1, 404);

    if (comic.cover_path) {
      const folder = getComicFolder(comic.cover_path);
      if (fs.existsSync(folder))
        fs.rmSync(folder, { recursive: true, force: true });
    }

    await db("comics").where({ id }).delete();
    ok(res, { id });
  } catch (err) {
    console.error("[delete comic]", err);
    fail(res, "Failed to delete comic", 1, 500);
  }
});
