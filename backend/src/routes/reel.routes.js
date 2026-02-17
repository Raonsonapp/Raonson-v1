import express from "express";
import {
  getReels,
  createReel,
  addView,
  toggleLike,
  toggleSave,
} from "../controllers/reel.controller.js";
import { authMiddleware } from "../middlewares/auth.middleware.js";

const router = express.Router();

router.get("/", authMiddleware, getReels);
router.post("/", authMiddleware, createReel);
router.post("/:id/view", authMiddleware, addView);
router.post("/:id/like", authMiddleware, toggleLike);
router.post("/:id/save", authMiddleware, toggleSave);

export default router;
