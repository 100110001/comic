import { Router } from "express";
import type { Request, Response } from "express";
import { imageSize } from "image-size";
import { db } from "../db/knex";
import { ok, fail } from "../utils/response";
import { config } from "../config";

export const chaptersRouter = Router();

const COMIC_ROOT = config.comicRoot;

function toUrl(filePath: string): string {
  return (
    "/static/" +
    filePath.replace(COMIC_ROOT, "").replace(/\\/g, "/").replace(/^\//, "")
  );
}

async function fillDimensions(images: any[]) {
  const missing = images.filter((img) => img.width == null);
  if (missing.length === 0) return;

  await Promise.all(
    missing.map(async (img) => {
      try {
        const dim = imageSize(img.path);
        img.width = dim.width ?? null;
        img.height = dim.height ?? null;
        await db("images")
          .where({ id: img.id })
          .update({ width: img.width, height: img.height });
      } catch {}
    }),
  );
}

chaptersRouter.get("/:id/images", async (req: Request, res: Response) => {
  try {
    const id = parseInt(String(req.params.id));
    if (isNaN(id)) return fail(res, "Invalid id");

    const chapter = await db("chapters").where({ id }).first();
    if (!chapter) return fail(res, "Chapter not found", 1, 404);

    const images = await db("images")
      .where({ chapter_id: id })
      .select("id", "filename", "path", "page_number", "width", "height")
      .orderBy("page_number");

    await fillDimensions(images);

    const data = images.map((img: any) => ({
      id: img.id,
      filename: img.filename,
      pageNumber: img.page_number,
      url: toUrl(img.path),
      width: img.width,
      height: img.height,
    }));

    ok(res, data);
  } catch (err) {
    fail(res, "Failed to fetch images", 1, 500);
  }
});
