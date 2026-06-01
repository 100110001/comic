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

export async function cacheGet<T>(key: string): Promise<T | null> {
  try {
    const val = await redis.get(key);
    return val ? (JSON.parse(val) as T) : null;
  } catch {
    return null;
  }
}

export async function cacheSet(key: string, value: unknown): Promise<void> {
  try {
    await redis.set(key, JSON.stringify(value), "EX", TTL);
  } catch {}
}

export async function cacheDel(key: string): Promise<void> {
  try {
    await redis.del(key);
  } catch {}
}
