export function roleMiddleware(requiredRole) {
  return (req, res, next) => {
    if (!req.user || !req.user.role) {
      return res.status(403).json({ error: "Access denied" });
    }

    if (req.user.role !== requiredRole) {
      return res.status(403).json({ error: "Insufficient permissions" });
    }

    next();
  };
}
