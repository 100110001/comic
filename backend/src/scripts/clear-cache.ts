import { invalidateProjectCache, redis } from "../db/redis";

const optional = process.argv.includes("--optional");

async function clearCache() {
  try {
    await redis.connect();
    const generation = await invalidateProjectCache();
    console.log(`缓存已清理（代际 ${generation}）`);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.warn(
      `Redis 不可用，缓存清理${optional ? "已跳过" : "失败"}: ${message}`,
    );
    if (!optional) process.exitCode = 1;
  } finally {
    redis.disconnect();
  }
}

void clearCache();
