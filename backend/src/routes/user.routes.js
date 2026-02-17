import express from "express";
import {
  getUserById,
  updateUser,
  deleteUser,
} from "../controllers/user.controller.js";
import { authMiddleware } from "../middlewares/auth.middleware.js";

const router = express.Router();

router.get("/:id", authMiddleware, getUserById);
router.put("/", authMiddleware, updateUser);
router.delete("/", authMiddleware, deleteUser);

export default router;
