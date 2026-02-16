import express from "express";
import {
  followUser,
  unfollowUser,
  acceptRequest,
  rejectRequest,
} from "../controllers/follow.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";

const router = express.Router();

// FOLLOW / REQUEST
router.post("/:id", authMiddleware, followUser);

// UNFOLLOW
router.delete("/:id", authMiddleware, unfollowUser);

// REQUESTS (PRIVATE ACCOUNTS)
router.post("/request/:id/accept", authMiddleware, acceptRequest);
router.post("/request/:id/reject", authMiddleware, rejectRequest);

export default router;
