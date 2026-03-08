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

// ── FIXED: specific routes MUST come before /:username ──
router.get("/me", authMiddleware, getMyProfile);
router.get("/notes/friends", authMiddleware, getFriendsNotes);  // ← пеш аз /:username
router.post("/note", authMiddleware, setNote);
router.put("/", authMiddleware, updateProfile);

// ── Dynamic route ─────────────────────────────────────────
router.get("/:username", authMiddleware, getProfile);           // ← охир

export default router;
