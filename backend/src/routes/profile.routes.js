import express from "express";
import { authMiddleware } from "../middlewares/auth.middleware.js";
import { getProfile } from "../controllers/profile.controller.js";

const router = express.Router();

router.get("/:id", authMiddleware, getProfile);

export default router;
