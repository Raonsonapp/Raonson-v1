import express from "express";
import { uploadMedia } from "../controllers/media.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";
import { uploadMiddleware } from "../middleware/upload.middleware.js";

const router = express.Router();

router.post(
  "/upload",
  authMiddleware,
  uploadMiddleware,
  uploadMedia
);

export default router;
