import { Router } from "express";
import type { Request, Response } from "express";
import { db } from "../db/knex";
import { ok, fail } from "../utils/response";

export const comicsRouter = Router();

comicsRouter.get("/", async (req: Request, res: Response) => {
  try {
    const pageOffset = Math.max(1, parseInt(String(req.query.pageOffset ?? 1)));
    const pageSize = Math.min(
      100,
      Math.max(1, parseInt(String(req.query.pageSize ?? 20))),
    );
    const keyword = String(req.query.keyword ?? "").trim();

    let query = db("comics").select(
      "id",
      "title",
      "author",
      "cover_path",
      "created_at",
    );

    if (keyword) {
      query = query
        .where("title", "like", `%${keyword}%`)
        .orWhere("author", "like", `%${keyword}%`);
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
      .select("id", "title", "author", "cover_path", "created_at")
      .where({ id })
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
