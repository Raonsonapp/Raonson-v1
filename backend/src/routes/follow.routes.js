import express from "express";
import {
  followUser,
  unfollowUser,
  acceptRequest,
  rejectRequest,
  getFollowers,
  getFollowing,
} from "../controllers/follow.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";

const router = express.Router();

// ✅ POST /follow/:id  → lib мефиристад
router.post("/:id", authMiddleware, followUser);

// ✅ DELETE /follow/:id → backend style
router.delete("/:id", authMiddleware, unfollowUser);

router.get("/:id/followers", authMiddleware, getFollowers);
router.get("/:id/following", authMiddleware, getFollowing);
router.post("/request/:id/accept", authMiddleware, acceptRequest);
router.post("/request/:id/reject", authMiddleware, rejectRequest);

export default router;
