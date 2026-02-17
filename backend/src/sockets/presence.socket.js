import { User } from "../models/user.model.js";

const onlineUsers = new Map(); // userId -> socketId

export default function presenceSocket(io, socket) {
  socket.on("presence:online", async ({ userId }) => {
    if (!userId) return;

    onlineUsers.set(userId, socket.id);

    await User.findByIdAndUpdate(userId, {
      lastSeen: null,
    });

    io.emit("presence:update", {
      userId,
      status: "online",
    });
  });

  socket.on("disconnect", async () => {
    for (const [userId, socketId] of onlineUsers.entries()) {
      if (socketId === socket.id) {
        onlineUsers.delete(userId);

        await User.findByIdAndUpdate(userId, {
          lastSeen: new Date(),
        });

        io.emit("presence:update", {
          userId,
          status: "offline",
        });

        break;
      }
    }
  });
}
