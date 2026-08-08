import { Router } from "express";
import type { Request, Response } from "express";
import { db } from "../db/knex";
import { ok, fail } from "../utils/response";
import { comicQuery } from "./comics";

export const mineRouter = Router();

// 最近阅读：每本漫画一条最新记录，按更新时间倒序
mineRouter.get("/recent", async (_req: Request, res: Response) => {
  try {
    const rows = await db("reading_progress as rp")
      .join("comics as c", "c.id", "rp.comic_id")
      .join("chapters as ch", "ch.id", "rp.chapter_id")
      .select(
        "c.id",
        "c.title",
        "c.author",
        "c.cover_path",
        "rp.chapter_id",
        "ch.title as chapter_title",
        "rp.page_number",
        "rp.updated_at",
      )
      .orderBy("rp.updated_at", "desc");

    ok(res, rows);
  } catch (err) {
    console.error("[mine recent]", err);
    fail(res, "Failed to fetch recent reading", 1, 500);
  }
});

// 收藏列表：按收藏时间倒序
mineRouter.get("/favorites", async (_req: Request, res: Response) => {
  try {
    const rows = await comicQuery()
      .join("favorites", "favorites.comic_id", "comics.id")
      .orderBy("favorites.created_at", "desc");

    ok(res, rows);
  } catch (err) {
    console.error("[mine favorites]", err);
    fail(res, "Failed to fetch favorites", 1, 500);
  }
});
