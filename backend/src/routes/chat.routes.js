import express from "express";
import {
  getChats,
  sendMessage,
  markSeen,
} from "../controllers/chat.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";

const router = express.Router();

router.get("/", authMiddleware, getChats);
router.post("/send", authMiddleware, sendMessage);
router.post("/:id/seen", authMiddleware, markSeen);

export default router;
