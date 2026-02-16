import express from "express";
import { authMiddleware } from "../middlewares/auth.middleware.js";
import {
  followUser,
  unfollowUser,
  acceptRequest,
  rejectRequest,
} from "../controllers/follow.controller.js";

const router = express.Router();

router.post("/:userId/follow", authMiddleware, followUser);
router.post("/:userId/unfollow", authMiddleware, unfollowUser);

router.post("/:userId/accept", authMiddleware, acceptRequest);
router.post("/:userId/reject", authMiddleware, rejectRequest);

export default router;
