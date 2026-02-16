import express from "express";
import {
  createReel,
  getReels,
  addView,
  toggleLike,
  toggleSave,
} from "../controllers/reel.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";

const router = express.Router();

router.get("/", authMiddleware, getReels);
router.post("/", authMiddleware, createReel);

router.post("/:id/view", authMiddleware, addView);
router.post("/:id/like", authMiddleware, toggleLike);
router.post("/:id/save", authMiddleware, toggleSave);

export default router;
