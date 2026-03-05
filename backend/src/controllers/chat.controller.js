import { Message } from "../models/message.model.js";
import { User } from "../models/user.model.js";

// CREATE OR GET CHAT
export async function getOrCreateChat(req, res) {
  try {
    const myId = req.user._id.toString();
    const otherId = req.params.userId;
    const chatId = [myId, otherId].sort().join("_");
    res.json({ chatId });
  } catch (e) {
    res.status(500).json({ message: "Get chat failed" });
  }
}

// GET USER CHATS — returns exactly what Flutter expects
// Shape: [{_id, peer: {_id, username, avatar, verified}, isMine, text, createdAt}]
export async function getChats(req, res) {
  try {
    const myId = req.user._id.toString();

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

    // Populate both sender and receiver
    await Message.populate(raw, [
      { path: "sender", select: "_id username avatar verified", model: "User" },
      { path: "receiver", select: "_id username avatar verified", model: "User" },
    ]);

    // Shape to Flutter format
    const result = raw
      .map((msg) => {
        const senderId = msg.sender?._id?.toString() ?? "";
        const isMine = senderId === myId;
        const peer = isMine ? msg.receiver : msg.sender;
        if (!peer || !peer.username) return null; // skip if peer missing
        return {
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
        };
      })
      .filter(Boolean);

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
      .populate("sender", "username avatar verified")
      .sort({ createdAt: 1 })
      .skip(skip)
      .limit(limit);

    res.json({ messages, page, limit });
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Get messages failed" });
  }
}

// SEND MESSAGE
export async function sendMessage(req, res) {
  try {
    const { chatId } = req.params;
    const { text, mediaUrl, receiverId } = req.body;

    if (!text && !mediaUrl) {
      return res.status(400).json({ message: "Message must have text or media" });
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
    console.error(e);
    res.status(500).json({ message: "Send message failed" });
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
    res.json({ read: true });
  } catch (e) {
    res.status(500).json({ message: "Mark read failed" });
  }
}

// DELETE MESSAGE
export async function deleteMessage(req, res) {
  try {
    await Message.findOneAndDelete({ _id: req.params.id, sender: req.user._id });
    res.json({ deleted: true });
  } catch (e) {
    res.status(500).json({ message: "Delete failed" });
  }
}
