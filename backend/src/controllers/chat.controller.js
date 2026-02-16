import { Chat } from "../models/chat.model.js";
import { Message } from "../models/message.model.js";
import { emitToUser } from "../socket/index.js";

// GET USER CHATS
export async function getChats(req, res) {
  const chats = await Chat.find({ users: req.user._id })
    .populate("users", "username avatar")
    .populate({
      path: "lastMessage",
      select: "text createdAt seen sender",
    })
    .sort({ updatedAt: -1 });

  res.json(chats);
}

// SEND MESSAGE
export async function sendMessage(req, res) {
  const { chatId, text } = req.body;

  const message = await Message.create({
    chat: chatId,
    sender: req.user._id,
    text,
  });

  await Chat.findByIdAndUpdate(chatId, {
    lastMessage: message._id,
    $set: { updatedAt: new Date() },
  });

  const chat = await Chat.findById(chatId);
  const receiver = chat.users.find(
    u => u.toString() !== req.user._id.toString()
  );

  // 🔴 REALTIME PUSH
  emitToUser(receiver, "new_message", {
    chatId,
    message,
  });

  res.json(message);
}

// MARK SEEN
export async function markSeen(req, res) {
  await Message.updateMany(
    { chat: req.params.id, seen: false },
    { seen: true }
  );
  res.json({ ok: true });
}
