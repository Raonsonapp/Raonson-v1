import express from "express";
import { search, searchUsers } from "../controllers/search.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";

const router = express.Router();

router.get("/", authMiddleware, search);
router.get("/users", authMiddleware, searchUsers);

export default router;
