import { redis } from "../config/redis.config.js";

export async function cacheGet(key) {
  const value = await redis.get(key);
  return value ? JSON.parse(value) : null;
}

export async function cacheSet(key, value, ttlSeconds = 300) {
  await redis.set(key, JSON.stringify(value), "EX", ttlSeconds);
}

export async function cacheDel(key) {
  await redis.del(key);
}
