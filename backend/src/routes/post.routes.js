import express from "express";
import {
  createPost,
  getFeed,
  getPost,
  deletePost,
  toggleLike,
  toggleSave,
} from "../controllers/post.controller.js";
import {
  getComments,
  addComment,
  deleteComment,
  toggleCommentLike,
} from "../controllers/comment.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";

const router = express.Router();

// ✅ GET /posts      → lib мефиристад (fetchFeed)
router.get("/", authMiddleware, getFeed);
// ✅ GET /posts/feed → ҳам кор мекунад (backward compat)
router.get("/feed", authMiddleware, getFeed);

router.get("/:id", authMiddleware, getPost);
router.post("/", authMiddleware, createPost);
router.delete("/:id", authMiddleware, deletePost);
router.post("/:id/like", authMiddleware, toggleLike);
router.post("/:id/save", authMiddleware, toggleSave);

// ✅ COMMENTS sub-routes (lib /posts/:id/comments ро мефиристад)
router.get("/:postId/comments", authMiddleware, getComments);
router.post("/:postId/comments", authMiddleware, addComment);
router.delete("/:postId/comments/:id", authMiddleware, deleteComment);
router.post("/:postId/comments/:id/like", authMiddleware, toggleCommentLike);

export default router;
