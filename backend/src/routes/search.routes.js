import express from "express";
import { authMiddleware } from "../middlewares/auth.middleware.js";
import {
  search,
  recent,
  clear,
} from "../controllers/search.controller.js";

const router = express.Router();

router.get("/", authMiddleware, search);
router.get("/recent", authMiddleware, recent);
router.delete("/recent", authMiddleware, clear);

export default router;
