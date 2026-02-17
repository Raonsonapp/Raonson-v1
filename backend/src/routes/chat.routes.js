import express from "express";
import {
  getChats,
  getMessages,
  sendMessage,
} from "../controllers/chat.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";

const router = express.Router();

router.get("/", authMiddleware, getChats);
router.get("/:chatId", authMiddleware, getMessages);
router.post("/:chatId", authMiddleware, sendMessage);

export default router;
