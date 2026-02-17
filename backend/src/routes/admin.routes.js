import express from "express";
import {
  getStats,
  banUser,
} from "../controllers/admin.controller.js";
import { authMiddleware } from "../middlewares/auth.middleware.js";
import { roleMiddleware } from "../middlewares/role.middleware.js";

const router = express.Router();

router.get("/stats", authMiddleware, roleMiddleware("admin"), getStats);
router.post("/ban/:id", authMiddleware, roleMiddleware("admin"), banUser);

export default router;
