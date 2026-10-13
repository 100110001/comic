import fs from "node:fs/promises";
import path from "node:path";
import { config } from "../config";
import { db } from "../db/knex";
import { redis } from "../db/redis";

async function librarySnapshot() {
  try {
    const rows = await db
      .raw(
        "SELECT (SELECT COUNT(*) FROM comics) AS comics, (SELECT COUNT(*) FROM chapters) AS chapters, (SELECT COUNT(*) FROM images) AS images",
      )
      .timeout(2500);
    const row = rows[0][0];
    return {
      status: "ready",
      comics: Number(row.comics),
      chapters: Number(row.chapters),
      images: Number(row.images),
    };
  } catch {
    return {
      status: "unavailable",
      comics: null,
      chapters: null,
      images: null,
    };
  }
}
async function cacheSnapshot() {
  const maxBytes = config.superResolution.maxBytes;
  try {
    let bytes = 0,
      count = 0;
    const directory = await fs.opendir(config.superResolution.cacheDir);
    for await (const entry of directory) {
      if (!entry.isFile() || !/^[a-f0-9]{64}\.webp$/.test(entry.name)) continue;
      try {
        const stat = await fs.stat(
          path.join(config.superResolution.cacheDir, entry.name),
        );
        bytes += stat.size;
        count++;
      } catch (error) {
        if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
      }
    }
    return { status: "ready", bytes, count, maxBytes };
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT")
      return { status: "missing", bytes: 0, count: 0, maxBytes };
    return { status: "unavailable", bytes: null, count: null, maxBytes };
  }
}
// 单次探测超时后保留底层在途任务，避免故障时反复占用连接或扫描目录。
let libraryWork: ReturnType<typeof librarySnapshot> | undefined;
let cacheWork: ReturnType<typeof cacheSnapshot> | undefined;
async function bounded<T>(work: Promise<T>, fallback: T): Promise<T> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  try {
    return await Promise.race([
      work,
      new Promise<T>((resolve) => {
        timer = setTimeout(() => resolve(fallback), 3000);
      }),
    ]);
  } finally {
    clearTimeout(timer);
  }
}
async function sample() {
  libraryWork ??= librarySnapshot().finally(() => {
    libraryWork = undefined;
  });
  cacheWork ??= cacheSnapshot().finally(() => {
    cacheWork = undefined;
  });
  const [library, cache] = await Promise.all([
    bounded(libraryWork, {
      status: "unavailable",
      comics: null,
      chapters: null,
      images: null,
    }),
    bounded(cacheWork, {
      status: "unavailable",
      bytes: null,
      count: null,
      maxBytes: config.superResolution.maxBytes,
    }),
  ]);
  return {
    sampledAt: new Date().toISOString(),
    library,
    cache,
    redis: redis.status === "ready" ? "ready" : "unavailable",
  };
}
let pending: ReturnType<typeof sample> | undefined;
let expires = 0;
export function infrastructureSnapshot() {
  if (!pending || Date.now() >= expires) {
    expires = Infinity;
    pending = sample().finally(() => {
      expires = Date.now() + 15000;
    });
  }
  return pending;
}
