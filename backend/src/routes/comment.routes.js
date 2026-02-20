import express from "express";
import {
  getComments,
  addComment,
  deleteComment,
  toggleCommentLike,
} from "../controllers/comment.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";

const router = express.Router();

router.get("/:postId", authMiddleware, getComments);
router.post("/:postId", authMiddleware, addComment);
router.delete("/:id", authMiddleware, deleteComment);
router.post("/:id/like", authMiddleware, toggleCommentLike);

export default router;
