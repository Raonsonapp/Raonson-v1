import express from "express";
import { createPost, getFeed } from "../controllers/post.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";

const router = express.Router();

router.post("/", authMiddleware, createPost);
router.get("/", getFeed);

export default router;
