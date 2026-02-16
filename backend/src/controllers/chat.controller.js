import { Chat } from "../models/chat.model.js";

// GET USER CHATS
export async function getChats(req, res) {
  const chats = await Chat.find({
    members: req.user._id,
  })
    .populate("members", "username avatar")
    .sort({ updatedAt: -1 });

  res.json(chats);
}

// SEND MESSAGE
export async function sendMessage(req, res) {
  const { chatId, text } = req.body;

  const chat = await Chat.findById(chatId);
  chat.messages.push({
    sender: req.user._id,
    text,
  });

  chat.updatedAt = new Date();
  await chat.save();

  res.json(chat.messages.at(-1));
}
