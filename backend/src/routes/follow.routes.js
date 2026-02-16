import express from "express";
import { authMiddleware } from "../middlewares/auth.middleware.js";
import {
  follow,
  unfollow,
  accept,
  reject,
} from "../controllers/follow.controller.js";

const router = express.Router();

router.post("/:id/follow", authMiddleware, follow);
router.post("/:id/unfollow", authMiddleware, unfollow);

// private account
router.post("/:id/accept", authMiddleware, accept);
router.post("/:id/reject", authMiddleware, reject);

export default router;
