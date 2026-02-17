import { Message } from "../models/message.model.js";

export async function sendMessage(req, res) {
  const { to, text } = req.body;

  const message = await Message.create({
    from: req.user._id,
    to,
    text,
  });

  res.json(message);
}

export async function getMessages(req, res) {
  const messages = await Message.find({
    $or: [
      { from: req.user._id, to: req.params.userId },
      { from: req.params.userId, to: req.user._id },
    ],
  }).sort({ createdAt: 1 });

  res.json(messages);
}
