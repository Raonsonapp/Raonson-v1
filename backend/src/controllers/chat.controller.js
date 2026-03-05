import { Message } from "../models/message.model.js";
import { User } from "../models/user.model.js";

// GET OR CREATE CHAT ID
export async function getOrCreateChat(req, res) {
  try {
    const myId = req.user._id.toString();
    const otherId = req.params.userId;
    const chatId = [myId, otherId].sort().join("_");
    res.json({ chatId });
  } catch (e) {
    console.error("getOrCreateChat error:", e);
    res.status(500).json({ message: "Failed" });
  }
}

// GET INBOX — returns [{_id, chatId, peer, isMine, text, createdAt}]
export async function getChats(req, res) {
  try {
    const myId = req.user._id.toString();

    // Get last message per chatId
    const raw = await Message.aggregate([
      {
        $match: {
          $or: [
            { sender: req.user._id },
            { receiver: req.user._id },
          ],
        },
      },
      { $sort: { createdAt: -1 } },
      {
        $group: {
          _id: "$chatId",
          lastMessage: { $first: "$$ROOT" },
        },
      },
      { $limit: 50 },
      { $replaceRoot: { newRoot: "$lastMessage" } },
    ]);

    // Populate sender and receiver
    await Message.populate(raw, [
      { path: "sender", select: "_id username avatar verified", model: "User" },
      { path: "receiver", select: "_id username avatar verified", model: "User" },
    ]);

    // Build Flutter-ready response
    const result = [];
    for (const msg of raw) {
      const senderId = msg.sender?._id?.toString() ?? msg.sender?.toString() ?? "";
      const isMine = senderId === myId;
      const peer = isMine ? msg.receiver : msg.sender;

      // Skip if peer not populated
      if (!peer || typeof peer !== "object" || !peer.username) continue;

      result.push({
        _id: msg._id,
        chatId: msg.chatId,
        isMine,
        text: msg.text || "",
        createdAt: msg.createdAt,
        read: msg.read,
        peer: {
          _id: peer._id,
          username: peer.username,
          avatar: peer.avatar || "",
          verified: peer.verified || false,
        },
      });
    }

    res.json(result);
  } catch (e) {
    console.error("getChats error:", e);
    res.status(500).json({ message: "Get chats failed" });
  }
}

// GET MESSAGES IN CHAT
export async function getMessages(req, res) {
  try {
    const { chatId } = req.params;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 40;
    const skip = (page - 1) * limit;

    const messages = await Message.find({ chatId })
      .populate("sender", "_id username avatar verified")
      .sort({ createdAt: 1 })
      .skip(skip)
      .limit(limit);

    res.json({ messages, page, limit });
  } catch (e) {
    console.error("getMessages error:", e);
    res.status(500).json({ message: "Failed" });
  }
}

// SEND MESSAGE
export async function sendMessage(req, res) {
  try {
    const { chatId } = req.params;
    const { text, mediaUrl, receiverId } = req.body;

    if (!text && !mediaUrl) {
      return res.status(400).json({ message: "Empty message" });
    }

    const message = await Message.create({
      chatId,
      sender: req.user._id,
      receiver: receiverId,
      text: text || "",
      mediaUrl: mediaUrl || "",
    });

    await message.populate([
      { path: "sender", select: "_id username avatar verified" },
      { path: "receiver", select: "_id username avatar verified" },
    ]);

    res.status(201).json(message);
  } catch (e) {
    console.error("sendMessage error:", e);
    res.status(500).json({ message: "Send failed" });
  }
}

// MARK AS READ
export async function markAsRead(req, res) {
  try {
    const { chatId } = req.params;
    await Message.updateMany(
      { chatId, receiver: req.user._id, read: false },
      { $set: { read: true } }
    );
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ message: "Failed" });
  }
}

// DELETE MESSAGE
export async function deleteMessage(req, res) {
  try {
    await Message.findOneAndDelete({ _id: req.params.id, sender: req.user._id });
    res.json({ deleted: true });
  } catch (e) {
    res.status(500).json({ message: "Failed" });
  }
                  }
