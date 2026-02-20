import mongoose from "mongoose";
import { connectDB } from "../config/db.config.js";

let isConnected = false;

export async function initDatabase() {
  if (isConnected) return;

  await connectDB();
  isConnected = true;

  mongoose.connection.on("disconnected", () => {
    isConnected = false;
    console.warn("⚠️ MongoDB disconnected");
  });
}
