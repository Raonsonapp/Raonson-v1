import { Server } from "socket.io";

let io;
const onlineUsers = new Map(); // userId -> socketId

export function initSocket(server) {
  io = new Server(server, {
    cors: { origin: "*" },
  });

  io.on("connection", socket => {
    console.log("🔌 socket connected:", socket.id);

    socket.on("online", userId => {
      onlineUsers.set(userId, socket.id);
      io.emit("online_users", Array.from(onlineUsers.keys()));
    });

    socket.on("disconnect", () => {
      for (const [uid, sid] of onlineUsers.entries()) {
        if (sid === socket.id) {
          onlineUsers.delete(uid);
          break;
        }
      }
      io.emit("online_users", Array.from(onlineUsers.keys()));
    });
  });
}

export function emitToUser(userId, event, payload) {
  const socketId = onlineUsers.get(userId.toString());
  if (socketId && io) {
    io.to(socketId).emit(event, payload);
  }
}
