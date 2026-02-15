import express from "express";
import {
  getStories,
  createStory,
  viewStory,
  likeStory,
  replyStory,
} from "../controllers/story.controller.js";

const router = express.Router();

router.get("/", getStories);
router.post("/", createStory);
router.post("/:id/view", viewStory);
router.post("/:id/like", likeStory);
router.post("/:id/reply", replyStory);

export default router;
