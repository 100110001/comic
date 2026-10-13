import { createHash } from "node:crypto";
import type { Request, RequestHandler } from "express";
import { apiCacheGet, cacheSet } from "../db/redis";

/** 仅缓存显式接入的稳定查询，身份与依赖组共同隔离响应。 */
export function cacheResponse(
  identity: (req: Request) => unknown | null,
  dependencies: (req: Request) => string[],
): RequestHandler {
  return async (req, res, next) => {
    if (req.method !== "GET") return next();
    const id = identity(req);
    if (id === null) return next();
    const groups = dependencies(req);
    const key =
      "api-v1:" +
      createHash("sha256")
        .update(JSON.stringify([id, groups]))
        .digest("hex");
    const cached = await apiCacheGet<unknown>(key, groups);
    res.locals.cacheOutcome =
      cached.generation === null
        ? "unavailable"
        : cached.value === null
          ? "miss"
          : "hit";
    if (cached.value !== null) {
      res.json(cached.value);
      return;
    }
    const json = res.json.bind(res);
    res.json = (body) => {
      if (
        cached.generation !== null &&
        res.statusCode === 200 &&
        body?.code === 0 &&
        Buffer.byteLength(JSON.stringify(body)) <= 2_000_000
      ) {
        // 保留查询开始时的版本，使失效前在途查询的晚写回不可被新请求读取。
        void cacheSet(key, body, cached.generation, 60);
      }
      return json(body);
    };
    next();
  };
}
