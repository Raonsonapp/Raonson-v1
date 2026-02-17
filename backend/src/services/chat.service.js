import { Message } from "../models/message.model.js";

export async function sendMessage(from, to, text) {
  const message = await Message.create({
    from,
    to,
    text,
  });

  return message;
}

export async function getChat(userA, userB) {
  return Message.find({
    $or: [
      { from: userA, to: userB },
      { from: userB, to: userA },
    ],
  })
    .sort({ createdAt: 1 })
    .limit(100);
}
