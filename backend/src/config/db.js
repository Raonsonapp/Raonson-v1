import mongoose from "mongoose";
import { logger } from "../core/logger.js";

export async function connectDB() {
  try {
    await mongoose.connect(process.env.MONGO_URI, {
      autoIndex: true,
    });
    logger.info("MongoDB connected");
  } catch (err) {
    logger.error("MongoDB connection failed", err);
    process.exit(1);
  }
}
