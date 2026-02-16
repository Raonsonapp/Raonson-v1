import { Chat } from "../models/chat.model.js";

// GET MY CHATS
export async function getChats(req, res) {
  const chats = await Chat.find({
    users: req.user._id,
  })
    .populate("users", "username avatar verified")
    .sort({ updatedAt: -1 });

  res.json(chats);
}

// SEND MESSAGE
export async function sendMessage(req, res) {
  const { chatId, text } = req.body;

  const chat = await Chat.findById(chatId);
  if (!chat) return res.status(404).json({ error: "Chat not found" });

  const message = {
    sender: req.user._id,
    text,
    seen: false,
  };

  chat.lastMessage = message;
  await chat.save();

  res.json(message);
}

// MARK SEEN
export async function markSeen(req, res) {
  await Chat.findByIdAndUpdate(req.params.id, {
    "lastMessage.seen": true,
  });

  res.json({ ok: true });
}
