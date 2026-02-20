import { Server } from "socket.io";
import chatSocket from "./chat.socket.js";
import notificationSocket from "./notification.socket.js";
import presenceSocket from "./presence.socket.js";

let io;

export function initSocket(httpServer) {
  io = new Server(httpServer, {
    cors: {
      origin: "*",
      methods: ["GET", "POST"],
    },
  });

  io.on("connection", (socket) => {
    presenceSocket(io, socket);
    chatSocket(io, socket);
    notificationSocket(io, socket);
  });

  return io;
}

export function getIO() {
  if (!io) {
    throw new Error("Socket.io not initialized");
  }
  return io;
}
