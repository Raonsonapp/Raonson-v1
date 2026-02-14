import express from "express";
import {
  createReel,
  getReels,
  addView,
  toggleLike,
  addComment,
} from "../controllers/reel.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";

const router = express.Router();

router.post("/", authMiddleware, createReel);
router.get("/", getReels);

router.post("/view/:reelId", addView);
router.post("/like/:reelId", authMiddleware, toggleLike);
router.post("/comment/:reelId", authMiddleware, addComment);

export default router;
