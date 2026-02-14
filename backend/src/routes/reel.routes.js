import express from "express";
import {
  getReels,
  addView,
  toggleLike,
} from "../controllers/reel.controller.js";

const router = express.Router();

router.get("/", getReels);
router.post("/:id/view", addView);
router.post("/:id/like", toggleLike);

export default router;
