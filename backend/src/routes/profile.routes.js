import express from "express";
import {
  getProfile,
  getMyProfile,
  updateProfile,
  setNote,
  getFriendsNotes,
} from "../controllers/profile.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";

const router = express.Router();

router.get("/me", authMiddleware, getMyProfile);
router.get("/:username", authMiddleware, getProfile);
router.put("/", authMiddleware, updateProfile);

// ── Notes ──
router.post("/note", authMiddleware, setNote);
router.get("/notes/friends", authMiddleware, getFriendsNotes);

export default router;
