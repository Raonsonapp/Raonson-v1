const requests = new Map();

export function rateLimitMiddleware(limit = 100, windowMs = 60000) {
  return (req, res, next) => {
    const ip = req.ip;
    const now = Date.now();

    if (!requests.has(ip)) {
      requests.set(ip, []);
    }

    const timestamps = requests.get(ip).filter(
      t => now - t < windowMs
    );

    timestamps.push(now);
    requests.set(ip, timestamps);

    if (timestamps.length > limit) {
      return res.status(429).json({
        error: "Too many requests",
      });
    }

    next();
  };
}
