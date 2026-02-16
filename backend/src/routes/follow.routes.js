import express from "express";
import { authMiddleware } from "../middlewares/auth.middleware.js";
import {
  follow,
  unfollow,
  accept,
  reject,
} from "../controllers/follow.controller.js";

const router = express.Router();

router.post("/:id", authMiddleware, follow);
router.delete("/:id", authMiddleware, unfollow);

router.post("/requests/:id/accept", authMiddleware, accept);
router.delete("/requests/:id/reject", authMiddleware, reject);

export default router;
