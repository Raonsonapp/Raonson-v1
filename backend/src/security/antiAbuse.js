const abuseTracker = new Map();

export function antiAbuse(action, limit = 100, windowMs = 60_000) {
  return (req, res, next) => {
    const userId = req.user?.id || req.ip;
    const key = `${userId}:${action}`;
    const now = Date.now();

    const entry = abuseTracker.get(key) || { count: 0, start: now };

    if (now - entry.start > windowMs) {
      entry.count = 0;
      entry.start = now;
    }

    entry.count += 1;
    abuseTracker.set(key, entry);

    if (entry.count > limit) {
      return res.status(403).json({
        error: "Abusive behavior detected",
      });
    }

    next();
  };
}
