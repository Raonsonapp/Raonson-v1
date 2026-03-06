import { Message } from "../models/message.model.js";

export async function getOrCreateChat(req, res) {
  try {
    const chatId = [req.user._id.toString(), req.params.userId].sort().join("_");
    res.json({ chatId });
  } catch (e) {
    res.status(500).json({ message: "Failed" });
  }
}

export async function getChats(req, res) {
  try {
    const myId = req.user._id.toString();

    const raw = await Message.aggregate([
      { $match: { $or: [{ sender: req.user._id }, { receiver: req.user._id }] } },
      { $sort: { createdAt: -1 } },
      { $group: { _id: "$chatId", msg: { $first: "$$ROOT" } } },
      { $replaceRoot: { newRoot: "$msg" } },
      { $limit: 50 },
    ]);

    await Message.populate(raw, [
      { path: "sender",   select: "_id username avatar verified" },
      { path: "receiver", select: "_id username avatar verified" },
    ]);

    const result = [];
    for (const m of raw) {
      const senderId = (m.sender?._id ?? m.sender)?.toString() ?? "";
      const isMine   = senderId === myId;
      const peer     = isMine ? m.receiver : m.sender;
      if (!peer || !peer.username) continue;
      result.push({
        _id:       m._id,
        chatId:    m.chatId,
        isMine,
        text:      m.text ?? "",
        createdAt: m.createdAt,
        peer: {
          _id:      peer._id,
          username: peer.username,
          avatar:   peer.avatar ?? "",
          verified: !!peer.verified,
        },
      });
    }

    res.json(result);
  } catch (e) {
    console.error("getChats:", e);
    res.status(500).json({ message: "Get chats failed" });
  }
}

export async function getMessages(req, res) {
  try {
    const msgs = await Message.find({ chatId: req.params.chatId })
      .populate("sender", "_id username avatar verified")
      .sort({ createdAt: 1 })
      .limit(50);
    res.json({ messages: msgs });
  } catch (e) {
    res.status(500).json({ message: "Failed" });
  }
}

export async function sendMessage(req, res) {
  try {
    const { text, receiverId } = req.body;
    const msg = await Message.create({
      chatId:   req.params.chatId,
      sender:   req.user._id,
      receiver: receiverId,
      text:     text ?? "",
    });
    await msg.populate("sender", "_id username avatar verified");
    res.status(201).json(msg);
  } catch (e) {
    console.error("sendMessage:", e);
    res.status(500).json({ message: "Send failed" });
  }
}

export async function markAsRead(req, res) {
  try {
    await Message.updateMany(
      { chatId: req.params.chatId, receiver: req.user._id },
      { read: true }
    );
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ message: "Failed" });
  }
}

export async function deleteMessage(req, res) {
  try {
    await Message.findOneAndDelete({ _id: req.params.id, sender: req.user._id });
    res.json({ deleted: true });
  } catch (e) {
    res.status(500).json({ message: "Failed" });
  }
          }
