import express from "express";
import {
  getReels,
  addView,
  toggleLike,
  toggleSave,
} from "../controllers/reel.controller.js";

const router = express.Router();

// FEED
router.get("/", getReels);

// VIEW
router.post("/:id/view", addView);

// LIKE
router.post("/:id/like", toggleLike);

// SAVE (BOOKMARK)
router.post("/:id/save", toggleSave);

export default router;
