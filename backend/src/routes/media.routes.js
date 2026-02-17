import express from "express";
import { uploadMedia } from "../controllers/media.controller.js";
import { authMiddleware } from "../middlewares/auth.middleware.js";
import { uploadMiddleware } from "../middlewares/upload.middleware.js";

const router = express.Router();

router.post(
  "/upload",
  authMiddleware,
  uploadMiddleware,
  uploadMedia
);

export default router;
