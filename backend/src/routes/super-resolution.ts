import { Router } from "express";
import { db } from "../db/knex";
import { ok, fail } from "../utils/response";
import {
  superResolution,
  SuperResolutionError,
} from "../services/super-resolution";

export const superResolutionRouter = Router();

superResolutionRouter.post("/jobs", async (req, res) => {
  const images = req.body?.images;
  if (
    !Array.isArray(images) ||
    images.length < 1 ||
    images.length > 3 ||
    images.some(
      (item) =>
        !item ||
        !Number.isSafeInteger(item.id) ||
        item.id <= 0 ||
        typeof item.version !== "string" ||
        !/^\d+-\d+$/.test(item.version),
    )
  ) {
    return fail(res, "请提交最多三张图片及原图版本");
  }
  try {
    const rows = await db("images")
      .whereIn(
        "id",
        images.map((item) => item.id),
      )
      .select("id", "path");
    const jobs = [];
    for (const [priority, item] of images.entries()) {
      const row = rows.find((row) => row.id === item.id);
      if (!row) return fail(res, "图片不存在", 1, 404);
      jobs.push(
        await superResolution.request(
          { id: row.id, path: row.path, version: item.version },
          priority,
        ),
      );
    }
    ok(res, jobs);
  } catch (error) {
    console.error("[超分] 提交失败", error);
    fail(
      res,
      error instanceof SuperResolutionError
        ? error.message
        : "超分提交失败，请检查后端配置",
      1,
      503,
    );
  }
});

superResolutionRouter.get("/jobs", (req, res) => {
  const keys =
    typeof req.query.keys === "string" ? req.query.keys.split(",") : [];
  if (
    keys.length < 1 ||
    keys.length > 3 ||
    keys.some((key) => !/^[a-f0-9]{64}$/.test(key))
  ) {
    return fail(res, "无效任务标识");
  }
  res.setHeader("Cache-Control", "no-store");
  ok(res, superResolution.status(keys));
});

superResolutionRouter.get("/files/:key", async (req, res) => {
  try {
    const file = await superResolution.file(String(req.params.key));
    res.sendFile(file, { maxAge: "1d", immutable: true }, (error) => {
      if (error && !res.headersSent) fail(res, "超分缓存已失效", 1, 404);
    });
  } catch {
    fail(res, "超分缓存不可用，请使用原图", 1, 404);
  }
});

superResolutionRouter.delete("/cache", async (_req, res) => {
  try {
    await superResolution.clear();
    ok(res, { cleared: true });
  } catch {
    fail(res, "超分缓存清理失败，请检查后端配置", 1, 503);
  }
});
