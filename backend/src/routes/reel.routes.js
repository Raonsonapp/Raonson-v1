import express from "express";
import {
  createReel,
  getReels,
  addView,
  toggleLike,
} from "../controllers/reel.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";

const router = express.Router();

router.post("/", authMiddleware, createReel);
router.get("/", getReels);
router.post("/view/:reelId", addView);

// ❤️ LIKE
router.post("/like/:reelId", authMiddleware, toggleLike);

export default router;
