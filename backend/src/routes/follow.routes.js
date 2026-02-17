import express from "express";
import {
  followUser,
  unfollowUser,
  acceptRequest,
  rejectRequest,
} from "../controllers/follow.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";

const router = express.Router();

router.post("/:id", authMiddleware, followUser);
router.delete("/:id", authMiddleware, unfollowUser);
router.post("/request/:id/accept", authMiddleware, acceptRequest);
router.post("/request/:id/reject", authMiddleware, rejectRequest);

export default router;
