import express from "express";
import { addComment, getComments } from "../controllers/comment.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";

const router = express.Router();

// COMMENTS FOR REELS
router.get("/reels/:targetId", getComments);
router.post("/reels/:targetId", authMiddleware, addComment);

// COMMENTS FOR POSTS
router.get("/posts/:targetId", getComments);
router.post("/posts/:targetId", authMiddleware, addComment);

export default router;
