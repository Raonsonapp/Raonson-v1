import express from "express";
import {
  getReels,
  createReel,
  addView,
  toggleLike,
  toggleSave,
  deleteReel,
  getReelComments,
  addReelComment,
} from "../controllers/reel.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";

const router = express.Router();

router.get("/", authMiddleware, getReels);
router.post("/", authMiddleware, createReel);
router.delete("/:id", authMiddleware, deleteReel);
router.post("/:id/view", authMiddleware, addView);
router.post("/:id/like", authMiddleware, toggleLike);
router.post("/:id/save", authMiddleware, toggleSave);
router.get("/:id/comments", authMiddleware, getReelComments);
router.post("/:id/comments", authMiddleware, addReelComment);

export default router;
