const spamMap = new Map();

export function antiSpam(req, res, next) {
  const key = `${req.ip}:${req.path}`;
  const now = Date.now();

  const record = spamMap.get(key) || { count: 0, last: now };

  if (now - record.last < 1000) {
    record.count += 1;
  } else {
    record.count = 1;
  }

  record.last = now;
  spamMap.set(key, record);

  if (record.count > 20) {
    return res.status(429).json({
      error: "Spam detected. Please slow down.",
    });
  }

  next();
}
