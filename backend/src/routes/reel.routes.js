import express from "express";
import {
  getReels,
  addView,
  toggleLike,
} from "../controllers/reel.controller.js";

const router = express.Router();

router.get("/", getReels);              // ✅ GET /reels
router.post("/:id/view", addView);      // ✅ POST /reels/:id/view
router.post("/:id/like", toggleLike);   // ✅ POST /reels/:id/like

export default router;
