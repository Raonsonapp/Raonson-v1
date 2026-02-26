import express from "express";
import {
  getStories,
  getMyStories,
  getViewers,
  createStory,
  viewStory,
  likeStory,
  deleteStory,
} from "../controllers/story.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";

const router = express.Router();

router.get("/", authMiddleware, getStories);
router.get("/my", authMiddleware, getMyStories);
router.get("/:id/viewers", authMiddleware, getViewers);
router.post("/", authMiddleware, createStory);
router.delete("/:id", authMiddleware, deleteStory);
router.post("/:id/view", authMiddleware, viewStory);
router.post("/:id/like", authMiddleware, likeStory);

export default router;
