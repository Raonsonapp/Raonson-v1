import { Notification } from "../models/notification.model.js";

export default function notificationSocket(io, socket) {
  socket.on("notification:subscribe", ({ userId }) => {
    if (!userId) return;
    socket.join(`notifications:${userId}`);
  });

  socket.on("notification:push", async (data) => {
    const { to, type, from, entityId } = data;
    if (!to || !type) return;

    const notification = await Notification.create({
      to,
      from,
      type,
      entityId,
      read: false,
    });

    io.to(`notifications:${to}`).emit("notification:new", notification);
  });

  socket.on("notification:read", async ({ notificationId }) => {
    if (!notificationId) return;
    await Notification.findByIdAndUpdate(notificationId, { read: true });
  });
}
