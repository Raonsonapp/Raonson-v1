import express from "express";
import {
  createStory,
  getStories,
  viewStory,
  toggleLikeStory,
} from "../controllers/story.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";

const router = express.Router();

router.get("/", authMiddleware, getStories);
router.post("/", authMiddleware, createStory);
router.post("/:id/view", authMiddleware, viewStory);
router.post("/:id/like", authMiddleware, toggleLikeStory);

export default router;
