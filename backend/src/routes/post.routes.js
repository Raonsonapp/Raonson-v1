import express from "express";
import { authMiddleware } from "../middlewares/auth.middleware.js";
import {
  createPost,
  getFeed,
  toggleLike,
  toggleSave,
} from "../controllers/post.controller.js";

const router = express.Router();

router.get("/feed", authMiddleware, getFeed);
router.post("/", authMiddleware, createPost);

router.post("/:id/like", authMiddleware, toggleLike);
router.post("/:id/save", authMiddleware, toggleSave);

export default router;
