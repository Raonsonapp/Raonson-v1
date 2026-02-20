import { Message } from "../models/message.model.js";

export default function chatSocket(io, socket) {
  socket.on("chat:join", ({ conversationId }) => {
    if (!conversationId) return;
    socket.join(conversationId);
  });

  socket.on("chat:typing", ({ conversationId, userId }) => {
    socket.to(conversationId).emit("chat:typing", { userId });
  });

  socket.on("chat:send", async (payload) => {
    const { conversationId, sender, receiver, text } = payload;
    if (!conversationId || !sender || !receiver || !text) return;

    const message = await Message.create({
      conversationId,
      sender,
      receiver,
      text,
      read: false,
    });

    io.to(conversationId).emit("chat:new", message);
  });

  socket.on("chat:read", async ({ messageId }) => {
    if (!messageId) return;
    await Message.findByIdAndUpdate(messageId, { read: true });
  });
}
