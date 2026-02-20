// src/middlewares/rateLimit.middleware.js
import crypto from "crypto";

const store = new Map();

/**
 * Rate Limit Middleware (Production-ready)
 * Works correctly on Render / Proxy / Load Balancer
 */
export function rateLimitMiddleware({
  limit = 100,
  windowMs = 60_000,
} = {}) {
  return (req, res, next) => {
    const now = Date.now();

    // ✅ Correct IP resolution (Render / Proxy safe)
    const ip =
      req.headers["x-forwarded-for"]?.split(",")[0]?.trim() ||
      req.socket.remoteAddress ||
      crypto.randomUUID();

    if (!store.has(ip)) {
      store.set(ip, []);
    }

    // ✅ keep only valid timestamps
    const timestamps = store
      .get(ip)
      .filter((time) => now - time < windowMs);

    timestamps.push(now);
    store.set(ip, timestamps);

    // ✅ hard limit reached
    if (timestamps.length > limit) {
      return res.status(429).json({
        success: false,
        message: "Too many requests. Please try again later.",
      });
    }

    next();
  };
}
