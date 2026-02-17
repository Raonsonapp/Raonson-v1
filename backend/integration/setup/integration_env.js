import dotenv from "dotenv";

dotenv.config({ path: ".env" });

export const integrationEnv = {
  NODE_ENV: "test",
  PORT: process.env.TEST_PORT || 4000,
  BASE_URL: "https://raonson-v1.onrender.com",
  JWT_SECRET: process.env.JWT_SECRET || "test_secret",
  DB_URI: process.env.TEST_DB_URI || "mongodb://127.0.0.1:27017/raonson_test",
};
