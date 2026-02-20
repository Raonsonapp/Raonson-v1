import { logger } from "./logger.js";

export function errorHandler(err, req, res, next) {
  const status = err.status || 500;

  logger.error(err.message, {
    path: req.originalUrl,
    method: req.method,
    status,
  });

  res.status(status).json({
    success: false,
    error: err.message || "Internal Server Error",
  });
}
