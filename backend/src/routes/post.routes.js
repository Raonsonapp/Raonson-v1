import express from "express";
import { createPost, getFeed } from "../controllers/post.controller.js";

const router = express.Router();

// ❌ authMiddleware-ро гирифтем (MVP)
router.post("/", createPost);
router.get("/", getFeed);

export default router;
