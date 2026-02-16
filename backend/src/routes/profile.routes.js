import express from "express";
import { authMiddleware } from "../middlewares/auth.middleware.js";
import {
  getProfile,
  getProfilePosts,
} from "../controllers/profile.controller.js";

const router = express.Router();

router.get("/:username", authMiddleware, getProfile);
router.get("/:username/posts", authMiddleware, getProfilePosts);

export default router;
