import express from "express";
import { getProfile, toggleFollow } from "../controllers/profile.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";

const router = express.Router();

router.get("/:id", authMiddleware, getProfile);
router.post("/:id/follow", authMiddleware, toggleFollow);

export default router;
