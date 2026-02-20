import express from "express";
import {
  getChats,
  getOrCreateChat,
  getMessages,
  sendMessage,
  markAsRead,
  deleteMessage,
} from "../controllers/chat.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";

const router = express.Router();

router.get("/", authMiddleware, getChats);
router.get("/with/:userId", authMiddleware, getOrCreateChat);
router.get("/:chatId/messages", authMiddleware, getMessages);
router.post("/:chatId/messages", authMiddleware, sendMessage);
router.post("/:chatId/read", authMiddleware, markAsRead);
router.delete("/messages/:id", authMiddleware, deleteMessage);

export default router;
