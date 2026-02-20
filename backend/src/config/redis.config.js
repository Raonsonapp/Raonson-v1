import Redis from "ioredis";

const {
  REDIS_URL,
  REDIS_HOST = "127.0.0.1",
  REDIS_PORT = 6379,
  REDIS_PASSWORD,
} = process.env;

export const redis = REDIS_URL
  ? new Redis(REDIS_URL, { maxRetriesPerRequest: 3 })
  : new Redis({
      host: REDIS_HOST,
      port: Number(REDIS_PORT),
      password: REDIS_PASSWORD || undefined,
      maxRetriesPerRequest: 3,
    });

redis.on("connect", () => {
  console.log("✅ Redis connected");
});

redis.on("error", (err) => {
  console.error("❌ Redis error:", err.message);
});
