import express from "express";
import { authMiddleware } from "../middlewares/auth.middleware.js";
import { toggleFollow } from "../controllers/follow.controller.js";

const router = express.Router();

router.post("/:id", authMiddleware, toggleFollow);

export default router;
