import mongoose from "mongoose";
import { integrationEnv } from "./integration_env.js";

export async function connectTestDB() {
  if (mongoose.connection.readyState === 1) return;

  await mongoose.connect(integrationEnv.DB_URI, {
    autoIndex: true,
  });
}

export async function clearTestDB() {
  const collections = mongoose.connection.collections;
  for (const key of Object.keys(collections)) {
    await collections[key].deleteMany({});
  }
}

export async function disconnectTestDB() {
  if (mongoose.connection.readyState !== 0) {
    await mongoose.disconnect();
  }
}
