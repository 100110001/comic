import { invalidateProjectCache, redis } from "../db/redis";

export async function clearCache(optional = false) {
  try {
    await redis.connect();
    const generation = await invalidateProjectCache();
    console.log(`缓存已清理（代际 ${generation}）`);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.warn(
      `Redis 不可用，缓存清理${optional ? "已跳过" : "失败"}: ${message}`,
    );
    if (!optional) throw err;
  } finally {
    redis.disconnect();
  }
}

if (require.main === module) {
  const args = process.argv.slice(2);
  if (args.some((arg) => arg !== "--optional")) {
    console.error("用法: cache:clear [--optional]");
    process.exitCode = 1;
  } else {
    void clearCache(args.includes("--optional")).catch(() => {
      process.exitCode = 1;
    });
  }
}
