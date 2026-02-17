import dotenv from "dotenv";
import mongoose from "mongoose";
import http from "http";

import app from "./app.js";
import { initDatabase } from "./core/database.js";
import { initSocket } from "./sockets/socket.js";

dotenv.config();

const PORT = process.env.PORT || 10000;
const BASE_URL = process.env.BASE_URL || "https://raonson-v1.onrender.com";

// ================= DATABASE =================
await initDatabase();

// ================= SERVER =================
const server = http.createServer(app);

// ================= SOCKET =================
initSocket(server);

// ================= START =================
server.listen(PORT, () => {
  console.log("====================================");
  console.log("🚀 Raonson Backend STARTED");
  console.log(`🌍 URL: ${BASE_URL}`);
  console.log(`📡 Port: ${PORT}`);
  console.log(`🧠 Node: ${process.version}`);
  console.log("====================================");
});

// ================= GRACEFUL SHUTDOWN =================
process.on("SIGINT", async () => {
  await mongoose.disconnect();
  process.exit(0);
});
