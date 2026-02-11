import express from "express";
import {
  createReel,
  getReels,
  addView,
} from "../controllers/reel.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";

const router = express.Router();

router.post("/", authMiddleware, createReel);
router.get("/", getReels);
router.post("/view/:reelId", addView);

export default router;
