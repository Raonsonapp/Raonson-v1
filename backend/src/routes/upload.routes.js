import express from "express";
import { upload } from "../middleware/upload.middleware.js";
import { uploadFile } from "../controllers/upload.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";

const router = express.Router();

router.post("/", authMiddleware, upload.single("file"), uploadFile);

export default router;
