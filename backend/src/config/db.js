import mongoose from "mongoose";
import { ENV } from "./env.js";

export async function connectDB() {
  try {
    await mongoose.connect(ENV.MONGO_URI, {
      dbName: "raonson",
    });
    console.log("🟢 MongoDB connected");
  } catch (e) {
    console.error("🔴 MongoDB error", e.message);
    process.exit(1);
  }
}
