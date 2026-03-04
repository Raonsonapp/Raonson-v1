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
    const { conversationId, chatId, sender, receiver, text } = payload;
    const roomId = chatId || conversationId;
    if (!roomId || !sender || !receiver || !text) return;

    const message = await Message.create({
      chatId: roomId,
      sender,
      receiver,
      text,
      read: false,
    });

    // Populate sender for the response
    await message.populate("sender", "username avatar verified");
    io.to(roomId).emit("chat:new", message);
  });

  socket.on("chat:read", async ({ messageId }) => {
    if (!messageId) return;
    await Message.findByIdAndUpdate(messageId, { read: true });
  });
            }
