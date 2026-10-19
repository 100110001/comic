import { Router } from "express";
import type { Request, Response } from "express";
import fs from "node:fs/promises";
import path from "node:path";
import { createHash } from "node:crypto";
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

function fileVersion(stat: { size: number; mtimeMs: number; ctimeMs: number }) {
  return `${stat.size}-${stat.mtimeMs}-${stat.ctimeMs}`;
}

async function inspectImage(filePath: string) {
  const url = imagePathUrl(path.relative(COMIC_ROOT, filePath));

  try {
    const stat = await fs.stat(filePath);
    if (!stat.isFile()) return { url, version: null };
    const version = fileVersion(stat);
    return { url: `${url}?v=${version}`, version };
  } catch {
    return { url, version: null };
  }
}

interface PendingImage extends ChapterImage {
  version: string;
  previousWidth: number | null;
  previousHeight: number | null;
}

// 只记住使用过的文件版本；重启或淘汰后按需重新校验，不扫描整库。
const verifiedDimensions = new Map<
  number,
  { path: string; version: string; width: number; height: number }
>();
const VERIFIED_LIMIT = 10000;

interface ChapterImage {
  id: number;
  filename: string;
  path: string;
  page_number: number;
  width: number | null;
  height: number | null;
}

async function fillDimensions(images: PendingImage[]) {
  await mapImages(images, async (img) => {
    try {
      const dim = await readImageDimensions(img.path);
      const current = await fs.stat(img.path);
      if (
        current.size !== dim.size ||
        current.mtimeMs !== dim.mtimeMs ||
        fileVersion(current) !== img.version
      )
        return;
      if (
        img.previousWidth !== dim.width ||
        img.previousHeight !== dim.height
      ) {
        const updated = await db("images")
          .where({
            id: img.id,
            path: img.path,
            width: img.previousWidth,
            height: img.previousHeight,
          })
          .update({ width: dim.width, height: dim.height });
        if (!updated) return;
      }
      img.width = dim.width;
      img.height = dim.height;
      verifiedDimensions.delete(img.id);
      verifiedDimensions.set(img.id, {
        path: img.path,
        version: img.version,
        width: dim.width,
        height: dim.height,
      });
      if (verifiedDimensions.size > VERIFIED_LIMIT)
        verifiedDimensions.delete(verifiedDimensions.keys().next().value!);
    } catch {
      // 图片无法读取时保留缺失尺寸，允许客户端继续尝试显示。
    }
  });
}

// 同章只探测一次，最多两个章节在后台补齐；额外章节下次请求再尝试。
const dimensionJobs = new Map<number, Promise<void>>();
function completeDimensions(id: number, images: PendingImage[]) {
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

    const chapter = await db("chapters").where({ id }).first();
    if (!chapter) return fail(res, "章节不存在，请刷新漫画详情", 1, 404);
    const comic = await db("comics")
      .where({ id: chapter.comic_id })
      .whereNull("deleted_at")
      .first();
    if (!comic) return fail(res, "漫画不存在或已删除，请刷新书库", 1, 404);

    const images = await db<ChapterImage & { chapter_id: number }>("images")
      .where({ chapter_id: id })
      .select("id", "filename", "path", "page_number", "width", "height")
      .orderBy("page_number");

    const files = await mapImages(images, (img) => inspectImage(img.path));
    if (images.length && files.every((file) => file.version === null)) {
      return fail(
        res,
        "章节原图不存在或不可访问，请检查文件并重新导入",
        1,
        404,
      );
    }
    // 缓存命中前也检查文件版本，同名替换不能继续返回旧尺寸和 URL。
    const fingerprint = createHash("sha256")
      .update(
        JSON.stringify(
          images.map((img, index) => [img, files[index]!.version]),
        ),
      )
      .digest("hex");
    const cacheKey = `chapter:${id}:images:${fingerprint}`;
    const cached = await cacheGet<unknown[]>(cacheKey);
    res.locals.cacheOutcome =
      cached.generation === null
        ? "unavailable"
        : cached.value
          ? "hit"
          : "miss";
    if (cached.value) return ok(res, cached.value);

    const pending = images.map((img, index) => {
      const version = files[index]!.version;
      const verified = verifiedDimensions.get(img.id);
      const valid =
        verified &&
        verified.path === img.path &&
        verified.version === version &&
        verified.width === img.width &&
        verified.height === img.height;
      return {
        ...img,
        previousWidth: img.width,
        previousHeight: img.height,
        version: version ?? "",
        width: valid ? img.width : null,
        height: valid ? img.height : null,
      };
    });
    const missing = pending.filter(
      (img) => img.width == null && img.version !== "",
    );
    if (!dimensionJobs.has(id)) await fillDimensions(missing.slice(0, 16));

    const data = pending.map((img, index) => ({
      id: img.id,
      filename: img.filename,
      pageNumber: img.page_number,
      url: files[index]!.url,
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
