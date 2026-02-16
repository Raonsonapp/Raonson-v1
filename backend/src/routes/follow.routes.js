import express from "express";
import {
  toggleFollow,
  isFollowing,
} from "../controllers/follow.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";

const router = express.Router();

// FOLLOW / UNFOLLOW
router.post("/:id", authMiddleware, toggleFollow);

// CHECK
router.get("/:id", authMiddleware, isFollowing);

export default router;
