import express from "express";
import {
  getUserById,
  updateUser,
  deleteUser,
  getUserPosts,
  getUserReels,
} from "../controllers/user.controller.js";
import {
  getFollowers,
  getFollowing,
} from "../controllers/follow.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";

const router = express.Router();

router.get("/:id", authMiddleware, getUserById);
router.put("/", authMiddleware, updateUser);
router.delete("/", authMiddleware, deleteUser);

// ✅ lib /users/:id/followers ва /users/:id/following мефиристад
router.get("/:id/followers", authMiddleware, getFollowers);
router.get("/:id/following", authMiddleware, getFollowing);

// ✅ lib /users/:id/posts ва /users/:id/reels мефиристад
router.get("/:id/posts", authMiddleware, getUserPosts);
router.get("/:id/reels", authMiddleware, getUserReels);

export default router;
