import express from "express";
import {
  toggleFollow,
  getFollowers,
  getFollowing,
} from "../controllers/follow.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";

const router = express.Router();

router.post("/:userId", authMiddleware, toggleFollow);
router.get("/:userId/followers", authMiddleware, getFollowers);
router.get("/:userId/following", authMiddleware, getFollowing);

export default router;
