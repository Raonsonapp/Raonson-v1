import { User } from "../models/user.model.js";

const onlineUsers = new Map(); // userId -> socketId

export default function presenceSocket(io, socket) {

  // ── User comes online ──
  socket.on("presence:online", async ({ userId }) => {
    if (!userId) return;
    onlineUsers.set(userId, socket.id);
    socket.userId = userId;

    await User.findByIdAndUpdate(userId, { lastSeen: null });

    io.emit("presence:update", { userId, status: "online", lastSeen: null });
    console.log(`[Presence] ${userId} online`);
  });

  // ── User disconnects ──
  socket.on("disconnect", async () => {
    const userId = socket.userId;
    if (!userId || !onlineUsers.has(userId)) return;

    onlineUsers.delete(userId);
    const now = new Date();

    await User.findByIdAndUpdate(userId, { lastSeen: now });

    io.emit("presence:update", {
      userId,
      status:   "offline",
      lastSeen: now.toISOString(),
    });
    console.log(`[Presence] ${userId} offline`);
  });

  // ── Check specific user status (returns isOnline + lastSeen) ──
  socket.on("presence:check", async ({ userId }) => {
    if (!userId) return;
    const isOnline = onlineUsers.has(userId);
    let lastSeen = null;

    if (!isOnline) {
      // Get lastSeen from DB when offline
      try {
        const user = await User.findById(userId).select("lastSeen");
        lastSeen = user?.lastSeen ? user.lastSeen.toISOString() : null;
      } catch (_) {}
    }

    socket.emit("presence:checked", { userId, isOnline, lastSeen });
  });
}
