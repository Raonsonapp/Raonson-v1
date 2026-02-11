import express from "express";
import {
  toggleFollow,
  getFollowers,
  getFollowing,
} from "../controllers/follow.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";

const router = express.Router();

router.post("/:userId", authMiddleware, toggleFollow);
router.get("/followers/:userId", getFollowers);
router.get("/following/:userId", getFollowing);

export default router;
