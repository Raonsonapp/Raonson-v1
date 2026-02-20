const blockedIPs = new Set();

export function blockIP(ip) {
  blockedIPs.add(ip);
}

export function unblockIP(ip) {
  blockedIPs.delete(ip);
}

export function ipBlockMiddleware(req, res, next) {
  if (blockedIPs.has(req.ip)) {
    return res.status(403).json({
      error: "Your IP has been blocked",
    });
  }
  next();
}
