import { Router } from "express";
import type { Request, Response } from "express";
import { db } from "../db/knex";
import { ok, fail } from "../utils/response";

export function comicQuery() {
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
    const random = req.query.random === "1";
    const pageSize = Math.min(
      random ? 500 : 100,
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
    const rows = await (random
      ? query.orderByRaw("RAND()")
      : query.orderBy("comics.title")
    )
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

    const favorite = await db("favorites").where({ comic_id: id }).first();
    const progress = await db("reading_progress")
      .where({ comic_id: id })
      .first();
    ok(res, {
      ...comic,
      favorited: !!favorite,
      progress: progress
        ? {
            chapterId: progress.chapter_id,
            pageNumber: progress.page_number,
          }
        : null,
      chapters,
    });
  } catch (err) {
    fail(res, "Failed to fetch comic", 1, 500);
  }
});

// 更新阅读进度（每本漫画只保留一条最新记录）
comicsRouter.put("/:id/progress", async (req: Request, res: Response) => {
  try {
    const id = parseInt(String(req.params.id));
    if (isNaN(id)) return fail(res, "Invalid id");

    const chapterId = parseInt(String(req.body?.chapterId));
    const pageNumber = parseInt(String(req.body?.pageNumber));
    if (isNaN(chapterId) || isNaN(pageNumber) || pageNumber < 0) {
      return fail(res, "chapterId and pageNumber are required");
    }

    const chapter = await db("chapters")
      .where({ id: chapterId, comic_id: id })
      .first();
    if (!chapter) return fail(res, "Chapter not found", 1, 404);

    await db("reading_progress")
      .insert({ comic_id: id, chapter_id: chapterId, page_number: pageNumber })
      .onConflict("comic_id")
      .merge({ chapter_id: chapterId, page_number: pageNumber });

    ok(res, { comicId: id, chapterId, pageNumber });
  } catch (err) {
    console.error("[update progress]", err);
    fail(res, "Failed to update progress", 1, 500);
  }
});

// 收藏（漫画级别开关）
comicsRouter.post("/:id/favorite", async (req: Request, res: Response) => {
  try {
    const id = parseInt(String(req.params.id));
    if (isNaN(id)) return fail(res, "Invalid id");

    const comic = await db("comics").where({ id }).first();
    if (!comic) return fail(res, "Comic not found", 1, 404);

    await db("favorites").insert({ comic_id: id }).onConflict("comic_id").ignore();
    ok(res, { comicId: id, favorited: true });
  } catch (err) {
    console.error("[favorite comic]", err);
    fail(res, "Failed to favorite comic", 1, 500);
  }
});

comicsRouter.delete("/:id/favorite", async (req: Request, res: Response) => {
  try {
    const id = parseInt(String(req.params.id));
    if (isNaN(id)) return fail(res, "Invalid id");

    await db("favorites").where({ comic_id: id }).del();
    ok(res, { comicId: id, favorited: false });
  } catch (err) {
    console.error("[unfavorite comic]", err);
    fail(res, "Failed to unfavorite comic", 1, 500);
  }
});
