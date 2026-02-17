import express from "express";
import {
  getStories,
  createStory,
  viewStory,
  likeStory,
} from "../controllers/story.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";

const router = express.Router();

router.get("/", authMiddleware, getStories);
router.post("/", authMiddleware, createStory);
router.post("/:id/view", authMiddleware, viewStory);
router.post("/:id/like", authMiddleware, likeStory);

export default router;
