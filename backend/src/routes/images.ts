import { Router } from "express";
import fs from "node:fs/promises";
import path from "node:path";
import { db } from "../db/knex";
import { config } from "../config";
import { ok, fail } from "../utils/response";
import { superResolution, SuperResolutionError } from "../services/super-resolution";

export const imagesRouter: Router = Router();

imagesRouter.post("/resolve", async (req, res) => {
  const { images, upscale } = req.body ?? {};
  if (typeof upscale !== "boolean" || !Array.isArray(images) || images.length < 1 || images.length > 3 || images.some((item) => !item || !Number.isSafeInteger(item.id) || item.id <= 0 || typeof item.version !== "string" || !/^\d+-\d+$/.test(item.version)) || new Set(images.map((item) => item.id)).size !== images.length) {
    return fail(res, "请提交超分开关及最多三张图片和原图版本");
  }
  res.setHeader("Cache-Control", "no-store");
  try {
    const rows = await db("images").whereIn("id", images.map((item) => item.id)).select("id", "path");
    const root = await fs.realpath(config.comicRoot);
    const sources = [];
    for (const item of images) {
      const row = rows.find((row) => row.id === item.id);
      if (!row) return fail(res, "图片不存在", 1, 404);
      const real = await fs.realpath(row.path);
      const relativeReal = path.relative(root, real);
      if (!relativeReal || relativeReal === ".." || relativeReal.startsWith(`..${path.sep}`) || path.isAbsolute(relativeReal)) return fail(res, "图片来源无效", 1, 400);
      const stat = await fs.stat(real);
      if (`${stat.size}-${Math.trunc(stat.mtimeMs)}` !== item.version) return fail(res, "原图已更新，请重新打开章节", 1, 409);
      const relative = path.relative(path.resolve(config.comicRoot), path.resolve(row.path));
      if (relative === ".." || relative.startsWith(`..${path.sep}`) || path.isAbsolute(relative)) return fail(res, "图片来源无效", 1, 400);
      sources.push({ id: item.id, path: row.path, version: item.version, url: `/static/${relative.replace(/\\/g, "/")}?v=${item.version}` });
    }
    const result = [];
    for (const [priority, source] of sources.entries()) {
      let job = null;
      let error: string | undefined;
      if (upscale) {
        try {
          job = await superResolution.request(source, priority);
        } catch (cause) {
          console.error("[图片] 超分提交失败", cause);
          error = cause instanceof SuperResolutionError ? cause.message : "超分暂不可用，继续显示原图";
        }
      }
      result.push({ id: source.id, url: source.url, superResolution: job, ...(error ? { error } : {}) });
    }
    ok(res, result);
  } catch (error) {
    console.error("[图片] 解析失败", error);
    fail(res, "图片读取失败，请重新打开章节", 1, 500);
  }
});
