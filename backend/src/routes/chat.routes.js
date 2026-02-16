import express from "express";
import { getChats, sendMessage } from "../controllers/chat.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";

const router = express.Router();

router.get("/", authMiddleware, getChats);
router.post("/send", authMiddleware, sendMessage);

export default router;
