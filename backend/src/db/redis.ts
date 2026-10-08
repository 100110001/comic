import Redis from "ioredis";
import { config } from "../config";

export const redis = new Redis({
  host: config.redis.host,
  port: config.redis.port,
  lazyConnect: true,
  enableOfflineQueue: false,
  maxRetriesPerRequest: 0,
  retryStrategy: () => null, // 不重试
});

redis.on("error", () => {}); // 静默，启动时统一打印

const TTL = 60 * 60 * 24; // 24h
const CACHE_PREFIX = "comic:";
const CACHE_GENERATION_KEY = `${CACHE_PREFIX}generation`;

export interface CacheEntry<T> {
  value: T | null;
  generation: string | null;
}

function dataKey(generation: string, key: string): string {
  return `${CACHE_PREFIX}${generation}:${key}`;
}

export async function cacheGet<T>(key: string): Promise<CacheEntry<T>> {
  try {
    const generation = (await redis.get(CACHE_GENERATION_KEY)) ?? "0";
    const val = await redis.get(dataKey(generation, key));
    return {
      value: val ? (JSON.parse(val) as T) : null,
      generation,
    };
  } catch {
    return { value: null, generation: null };
  }
}

export async function cacheSet(
  key: string,
  value: unknown,
  generation: string | null,
): Promise<void> {
  if (generation == null) return;

  try {
    await redis.set(dataKey(generation, key), JSON.stringify(value), "EX", TTL);
  } catch {
    // Redis 缓存不可用时继续返回业务结果。
  }
}

export async function invalidateProjectCache(): Promise<number> {
  return redis.incr(CACHE_GENERATION_KEY);
}
