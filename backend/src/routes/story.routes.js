import express from "express";
import {
  getStories,
  createStory,
  viewStory,
  likeStory,
} from "../controllers/story.controller.js";

const router = express.Router();

router.get("/", getStories);
router.post("/", createStory);
router.post("/:id/view", viewStory);
router.post("/:id/like", likeStory);

export default router;
