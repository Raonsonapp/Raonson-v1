const SERVICE_NAME = "Raonson-Backend";
const BASE_URL = "https://raonson-v1.onrender.com";

function log(level, message, meta = {}) {
  const entry = {
    service: SERVICE_NAME,
    level,
    message,
    baseUrl: BASE_URL,
    timestamp: new Date().toISOString(),
    ...meta,
  };
  console.log(JSON.stringify(entry));
}

export const logger = {
  info: (msg, meta) => log("INFO", msg, meta),
  warn: (msg, meta) => log("WARN", msg, meta),
  error: (msg, meta) => log("ERROR", msg, meta),
};
