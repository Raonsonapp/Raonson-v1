import express from "express";
import {
  likeTarget,
  unlikeTarget,
} from "../controllers/like.controller.js";
import { authMiddleware } from "../middlewares/auth.middleware.js";

const router = express.Router();

router.post("/", authMiddleware, likeTarget);
router.delete("/", authMiddleware, unlikeTarget);

export default router;
