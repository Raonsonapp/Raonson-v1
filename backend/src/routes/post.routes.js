import express from "express";
import {
  createPost,
  getFeed,
  toggleLike,
  toggleSave,
} from "../controllers/post.controller.js";
import { authMiddleware } from "../middlewares/auth.middleware.js";

const router = express.Router();

router.get("/feed", authMiddleware, getFeed);
router.post("/", authMiddleware, createPost);
router.post("/:id/like", authMiddleware, toggleLike);
router.post("/:id/save", authMiddleware, toggleSave);

export default router;
