import express from "express";
import {
  getComments,
  addComment,
  toggleLikeComment,
} from "../controllers/comment.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";

const router = express.Router();

router.get("/:postId", authMiddleware, getComments);
router.post("/:postId", authMiddleware, addComment);
router.post("/like/:id", authMiddleware, toggleLikeComment);

export default router;
