export const logger = {
  info: (...args) => console.log("ℹ️", ...args),
  warn: (...args) => console.warn("⚠️", ...args),
  error: (...args) => console.error("❌", ...args),
};
