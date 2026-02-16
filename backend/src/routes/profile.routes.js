import express from "express";
import { authMiddleware } from "../middlewares/auth.middleware.js";
import { viewProfile } from "../controllers/profile.controller.js";

const router = express.Router();

router.get("/:username", authMiddleware, viewProfile);

export default router;
