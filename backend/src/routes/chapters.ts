import { Router } from "express";
import type { Request, Response } from "express";
import fs from "node:fs/promises";
import path from "node:path";
import { db } from "../db/knex";
import { ok, fail } from "../utils/response";
import { config } from "../config";
import { cacheGet, cacheSet } from "../db/redis";
import {
  imagePathUrl,
  mapImages,
  readImageDimensions,
} from "../utils/image-metadata";

export const chaptersRouter: Router = Router();

const COMIC_ROOT = config.comicRoot;

async function toUrl(filePath: string): Promise<string> {
  const url = imagePathUrl(path.relative(COMIC_ROOT, filePath));

  try {
    const stat = await fs.stat(filePath);
    return `${url}?v=${stat.size}-${Math.trunc(stat.mtimeMs)}`;
  } catch {
    return url;
  }
}

interface ChapterImage {
  id: number;
  filename: string;
  path: string;
  page_number: number;
  width: number | null;
  height: number | null;
}

async function fillDimensions(images: ChapterImage[]) {
  await mapImages(images, async (img) => {
    try {
      const dim = await readImageDimensions(img.path);
      const current = await fs.stat(img.path);
      if (current.size !== dim.size || current.mtimeMs !== dim.mtimeMs) return;
      const updated = await db("images")
        .where({ id: img.id, path: img.path })
        .whereNull("width")
        .update({ width: dim.width, height: dim.height });
      if (updated) {
        img.width = dim.width;
        img.height = dim.height;
      }
    } catch {
      // 图片无法读取时保留缺失尺寸，允许客户端继续尝试显示。
    }
  });
}

// 同章只探测一次，最多两个章节在后台补齐；额外章节下次请求再尝试。
const dimensionJobs = new Map<number, Promise<void>>();
function completeDimensions(id: number, images: ChapterImage[]) {
  if (dimensionJobs.has(id) || dimensionJobs.size >= 2 || images.length === 0)
    return;
  const job = fillDimensions(images.map((image) => ({ ...image })))
    .catch((error: unknown) => console.error("[图片] 尺寸补齐失败", error))
    .finally(() => dimensionJobs.delete(id));
  dimensionJobs.set(id, job);
}

chaptersRouter.get("/:id/images", async (req: Request, res: Response) => {
  try {
    const id = parseInt(String(req.params.id));
    if (isNaN(id)) return fail(res, "Invalid id");

    const cacheKey = `chapter:${id}:images`;
    const cached = await cacheGet<unknown[]>(cacheKey);
    res.locals.cacheOutcome =
      cached.generation === null
        ? "unavailable"
        : cached.value
          ? "hit"
          : "miss";
    if (cached.value) {
      console.log(`[cache hit] ${cacheKey}`);
      return ok(res, cached.value);
    }
    console.log(`[cache miss] ${cacheKey}`);

    const chapter = await db("chapters").where({ id }).first();
    if (!chapter) return fail(res, "章节不存在，请刷新漫画详情", 1, 404);

    const images = await db<ChapterImage & { chapter_id: number }>("images")
      .where({ chapter_id: id })
      .select("id", "filename", "path", "page_number", "width", "height")
      .orderBy("page_number");

    const urls = await mapImages(images, (img) => toUrl(img.path));
    if (images.length && urls.every((url) => !url.includes("?v="))) {
      return fail(
        res,
        "章节原图不存在或不可访问，请检查文件并重新导入",
        1,
        404,
      );
    }
    const missing = images.filter(
      (img, index) => img.width == null && urls[index]!.includes("?v="),
    );
    if (!dimensionJobs.has(id)) await fillDimensions(missing.slice(0, 16));

    const data = images.map((img, index) => ({
      id: img.id,
      filename: img.filename,
      pageNumber: img.page_number,
      url: urls[index],
      width: img.width,
      height: img.height,
    }));

    const remaining = missing.filter((img) => img.width == null);
    await cacheSet(
      cacheKey,
      data,
      cached.generation,
      remaining.length ? 5 : undefined,
    );
    ok(res, data);
    completeDimensions(id, remaining);
  } catch {
    fail(res, "Failed to fetch images", 1, 500);
  }
});
