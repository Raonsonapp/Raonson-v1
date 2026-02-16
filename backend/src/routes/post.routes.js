import express from "express";
import {
  getFeed,
  toggleLike,
  toggleSave,
} from "../controllers/post.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";

const router = express.Router();

router.get("/feed", authMiddleware, getFeed);
router.post("/:id/like", authMiddleware, toggleLike);
router.post("/:id/save", authMiddleware, toggleSave);

export default router;
