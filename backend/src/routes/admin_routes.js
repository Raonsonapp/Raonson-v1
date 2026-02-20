import express from "express";
import { getStats, banUser, unbanUser } from "../controllers/admin.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";
import { roleMiddleware } from "../middleware/role.middleware.js";

const router = express.Router();

router.get("/stats", authMiddleware, roleMiddleware("admin"), getStats);
router.post("/ban/:id", authMiddleware, roleMiddleware("admin"), banUser);
router.post("/unban/:id", authMiddleware, roleMiddleware("admin"), unbanUser);

export default router;
