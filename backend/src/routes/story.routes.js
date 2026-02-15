import express from "express";
import {
  getStories,
  createStory,
  viewStory,
} from "../controllers/story.controller.js";

const router = express.Router();

// GET all stories (24h)
router.get("/", getStories);

// CREATE story
router.post("/", createStory);

// VIEW story
router.post("/:id/view", viewStory);

export default router;
