import express from "express";
import {
  getReels,
  addView,
  likeReel,
  shareReel,
  saveReel,
} from "../controllers/reel.controller.js";

const router = express.Router();

router.get("/", getReels);
router.post("/:id/view", addView);
router.post("/:id/like", likeReel);
router.post("/:id/share", shareReel);
router.post("/:id/save", saveReel);

export default router;
