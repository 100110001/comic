import { Router } from "express";
import type { Request, Response } from "express";
import { db } from "../db/knex";
import { ok, fail } from "../utils/response";

export const favoriteAuthorsRouter = Router();

// 收藏作者列表（含作品数）
favoriteAuthorsRouter.get("/", async (_req: Request, res: Response) => {
  try {
    const rows = await db("favorite_authors as fa")
      .leftJoin("comics as c", "c.author", "fa.author")
      .select(
        "fa.author",
        db.raw("COUNT(DISTINCT c.id) as comic_count"),
        "fa.created_at",
      )
      .groupBy("fa.author", "fa.created_at")
      .orderBy("fa.created_at", "desc");

    ok(res, rows);
  } catch (err) {
    console.error("[favorite authors]", err);
    fail(res, "Failed to fetch favorite authors", 1, 500);
  }
});

// 收藏作者（幂等）
favoriteAuthorsRouter.post("/", async (req: Request, res: Response) => {
  try {
    const author = String(req.body?.author ?? "").trim();
    if (!author) return fail(res, "author is required");

    await db("favorite_authors")
      .insert({ author })
      .onConflict("author")
      .ignore();
    ok(res, { author, favorited: true });
  } catch (err) {
    console.error("[favorite author]", err);
    fail(res, "Failed to favorite author", 1, 500);
  }
});

// 取消收藏作者
favoriteAuthorsRouter.delete("/", async (req: Request, res: Response) => {
  try {
    const author = String(req.body?.author ?? "").trim();
    if (!author) return fail(res, "author is required");

    await db("favorite_authors").where({ author }).del();
    ok(res, { author, favorited: false });
  } catch (err) {
    console.error("[unfavorite author]", err);
    fail(res, "Failed to unfavorite author", 1, 500);
  }
});
