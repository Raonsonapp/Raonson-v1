import { Notification } from "../models/notification.model.js";

export default function notificationSocket(io, socket) {
  socket.on("notification:subscribe", ({ userId }) => {
    if (!userId) return;
    socket.join(`notifications:${userId}`);
  });

  socket.on("notification:push", async (data) => {
    const { to, type, from, entityId } = data;
    if (!to || !type) return;

    try {
      const notification = await Notification.create({
        user: to,          // ✅ model field name
        fromUser: from,    // ✅ model field name
        type,
        targetId: entityId,
        read: false,
      });

      io.to(`notifications:${to}`).emit("notification:new", notification);
    } catch (e) {
      console.error("Notification push error:", e.message);
    }
  });

  socket.on("notification:read", async ({ notificationId }) => {
    if (!notificationId) return;
    try {
      await Notification.findByIdAndUpdate(notificationId, { read: true });
    } catch (e) {
      console.error("Notification read error:", e.message);
    }
  });
}
