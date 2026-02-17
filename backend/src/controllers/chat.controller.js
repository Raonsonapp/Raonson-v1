import { Message } from "../models/message.model.js";

// GET USER CHATS
export async function getChats(req, res) {
  const userId = req.user.id;

  const chats = await Message.find({
    participants: userId,
  })
    .sort({ updatedAt: -1 })
    .limit(50);

  res.json(chats);
}

// GET MESSAGES IN CHAT
export async function getMessages(req, res) {
  const { chatId } = req.params;

  const messages = await Message.find({ chatId })
    .sort({ createdAt: 1 });

  res.json(messages);
}

// SEND MESSAGE
export async function sendMessage(req, res) {
  const { chatId } = req.params;
  const { text, mediaUrl } = req.body;

  const message = await Message.create({
    chatId,
    sender: req.user.id,
    text,
    mediaUrl,
  });

  res.json(message);
}

// MARK CHAT AS READ
export async function markAsRead(req, res) {
  const { chatId } = req.params;

  await Message.updateMany(
    { chatId, read: false },
    { $set: { read: true } }
  );

  res.json({ read: true });
}
