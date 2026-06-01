import { Router } from "express";
import type { Request, Response } from "express";
import fs from "fs";
import path from "path";
import { db } from "../db/knex";
import { ok, fail } from "../utils/response";

const COMIC_ROOT = "E:\\comic";

function getComicFolder(coverPath: string): string {
  const rel = coverPath.replace(COMIC_ROOT + "\\", "");
  return path.join(COMIC_ROOT, rel.split("\\")[0]!);
}

export const comicsRouter = Router();

comicsRouter.get("/", async (req: Request, res: Response) => {
  try {
    const pageOffset = Math.max(1, parseInt(String(req.query.pageOffset ?? 1)));
    const pageSize = Math.min(
      100,
      Math.max(1, parseInt(String(req.query.pageSize ?? 20))),
    );
    const keyword = String(req.query.keyword ?? "").trim();

    let query = db("comics")
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
      .orderBy("title")
      .limit(pageSize)
      .offset((pageOffset - 1) * pageSize);

    ok(res, rows, { pageOffset, pageSize, total });
  } catch (err) {
    console.error("[comics]", err);
    fail(res, "Failed to fetch comics", 1, 500);
  }
});

comicsRouter.get("/:id", async (req: Request, res: Response) => {
  try {
    const id = parseInt(String(req.params.id));
    if (isNaN(id)) return fail(res, "Invalid id");

    const comic = await db("comics")
      .select(
        "comics.id", "comics.title", "comics.author", "comics.cover_path", "comics.created_at",
        db.raw("COUNT(DISTINCT chapters.id) as chapter_count"),
        db.raw("COUNT(DISTINCT images.id) as image_count"),
      )
      .leftJoin("chapters", "comics.id", "chapters.comic_id")
      .leftJoin("images", "chapters.id", "images.chapter_id")
      .where("comics.id", id)
      .groupBy("comics.id")
      .first();
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

comicsRouter.delete("/:id", async (req: Request, res: Response) => {
  try {
    const id = parseInt(String(req.params.id));
    if (isNaN(id)) return fail(res, "Invalid id");

    const comic = await db("comics").where({ id }).first();
    if (!comic) return fail(res, "Comic not found", 1, 404);

    // 删本地文件夹
    if (comic.cover_path) {
      const folder = getComicFolder(comic.cover_path);
      if (fs.existsSync(folder)) {
        fs.rmSync(folder, { recursive: true, force: true });
      }
    }

    // 删数据库（cascade 自动删 chapters + images）
    await db("comics").where({ id }).delete();

    ok(res, { id });
  } catch (err) {
    console.error("[delete comic]", err);
    fail(res, "Failed to delete comic", 1, 500);
  }
});
