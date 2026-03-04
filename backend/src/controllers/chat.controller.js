import { Message } from "../models/message.model.js";
import { User } from "../models/user.model.js";

// CREATE OR GET CHAT (stable chatId for 1-on-1)
export async function getOrCreateChat(req, res) {
  try {
    const myId = req.user._id.toString();
    const otherId = req.params.userId;
    const chatId = [myId, otherId].sort().join("_");
    res.json({ chatId });
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Get chat failed" });
  }
}

// GET USER CHATS - inbox list with populated sender/receiver
export async function getChats(req, res) {
  try {
    // Step 1: get last message per chat using simple find + group
    const messages = await Message.aggregate([
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

    // Step 2: populate sender and receiver using Mongoose
    const populated = await Message.populate(messages, [
      { path: "sender", select: "username avatar verified", model: User },
      { path: "receiver", select: "username avatar verified", model: User },
    ]);

    res.json(populated);
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

    await message.populate("sender", "username avatar verified");
    res.status(201).json(message);
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Send message failed" });
  }
}

// MARK CHAT AS READ
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
