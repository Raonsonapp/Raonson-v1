import express from "express";
import {
  getProfile,
  updateProfile,
} from "../controllers/profile.controller.js";
import { authMiddleware } from "../middlewares/auth.middleware.js";

const router = express.Router();

router.get("/:username", authMiddleware, getProfile);
router.put("/", authMiddleware, updateProfile);

export default router;
