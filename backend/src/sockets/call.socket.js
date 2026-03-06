// Map: userId -> socketId
const onlineUsers = new Map();

export default function callSocket(io, socket) {

  // Register user socket
  socket.on("user:register", (userId) => {
    if (!userId) return;
    onlineUsers.set(userId, socket.id);
    socket.userId = userId;
  });

  // ── OFFER: Caller sends to callee ──
  socket.on("call:offer", ({ to, offer, callType, from, fromUsername, fromAvatar }) => {
    const targetSocket = onlineUsers.get(to);
    if (!targetSocket) return;
    io.to(targetSocket).emit("call:incoming", {
      from,
      fromUsername,
      fromAvatar,
      offer,
      callType,
    });
  });

  // ── ANSWER: Callee sends back to caller ──
  socket.on("call:answer", ({ to, answer }) => {
    const targetSocket = onlineUsers.get(to);
    if (!targetSocket) return;
    io.to(targetSocket).emit("call:answered", { answer });
  });

  // ── ICE CANDIDATE: Both sides exchange ──
  socket.on("call:ice-candidate", ({ to, candidate }) => {
    const targetSocket = onlineUsers.get(to);
    if (!targetSocket) return;
    io.to(targetSocket).emit("call:ice-candidate", { candidate });
  });

  // ── END CALL ──
  socket.on("call:end", ({ to }) => {
    const targetSocket = onlineUsers.get(to);
    if (!targetSocket) return;
    io.to(targetSocket).emit("call:ended");
  });

  // ── DECLINE ──
  socket.on("call:decline", ({ to }) => {
    const targetSocket = onlineUsers.get(to);
    if (!targetSocket) return;
    io.to(targetSocket).emit("call:declined");
  });

  // Cleanup on disconnect
  socket.on("disconnect", () => {
    if (socket.userId) {
      onlineUsers.delete(socket.userId);
    }
  });
}
