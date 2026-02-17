import dotenv from "dotenv";

dotenv.config();

export const E2E_ENV = {
  NODE_ENV: "test",
  API_BASE_URL: process.env.E2E_BASE_URL || "http://localhost:4000",
  MONGO_URI: process.env.E2E_MONGO_URI,
  JWT_SECRET: process.env.JWT_SECRET,
};

if (!E2E_ENV.MONGO_URI || !E2E_ENV.JWT_SECRET) {
  throw new Error("E2E environment variables are not fully defined");
}
