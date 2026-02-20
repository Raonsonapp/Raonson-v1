import dotenv from "dotenv";
import mongoose from "mongoose";
import http from "http";

import app from "./app.js";
import { initDatabase } from "./core/database.js";
import { initSocket } from "./sockets/socket.js";

dotenv.config();

const PORT = process.env.PORT || 10000;

// ================= SERVER =================
const server = http.createServer(app);

// ================= SOCKET =================
initSocket(server);

// ================= START SERVER FIRST =================
server.listen(PORT, () => {
  console.log("====================================");
  console.log("🚀 Raonson Backend STARTED");
  console.log(`📡 Port: ${PORT}`);
  console.log(`🧠 Node: ${process.version}`);
  console.log("====================================");
});

// ================= DATABASE (AFTER LISTEN) =================
initDatabase()
  .then(() => console.log("✅ MongoDB connected"))
  .catch(err => console.error("❌ MongoDB error:", err));

// ================= GRACEFUL SHUTDOWN =================
process.on("SIGINT", async () => {
  await mongoose.disconnect();
  process.exit(0);
});
