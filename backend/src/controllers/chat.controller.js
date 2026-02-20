import { Message } from "../models/message.model.js";
import { v4 as uuidv4 } from "uuid";

// CREATE OR GET CHAT (by participants)
export async function getOrCreateChat(req, res) {
  try {
    const { userId } = req.params; // other user
    const myId = req.user._id.toString();
    const otherId = userId;

    // Stable chatId for 1-on-1 chat
    const chatId = [myId, otherId].sort().join("_");

    res.json({ chatId });
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Get chat failed" });
  }
}

// GET USER CHATS (list of recent conversations)
export async function getChats(req, res) {
  try {
    const userId = req.user._id.toString();

    // Find unique chatIds where user is sender or receiver
    const messages = await Message.aggregate([
      {
        $match: {
          $or: [
            { sender: req.user._id },
            { receiver: req.user._id },
          ],
        },
      },
      {
        $sort: { createdAt: -1 },
      },
      {
        $group: {
          _id: "$chatId",
          lastMessage: { $first: "$$ROOT" },
        },
      },
      { $limit: 50 },
    ]);

    res.json(messages);
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Get chats failed" });
  }
}

// GET MESSAGES IN CHAT
export async function getMessages(req, res) {
  try {
    const { chatId } = req.params;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 30;
    const skip = (page - 1) * limit;

    const messages = await Message.find({ chatId })
      .populate("sender", "username avatar")
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
