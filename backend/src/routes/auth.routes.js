import express from "express";
import {
  sendOtp,
  verifyOtp,
  verifyGmail,
} from "../controllers/auth.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";

const router = express.Router();

router.post("/send-otp", sendOtp);
router.post("/verify-otp", verifyOtp);
router.post("/verify-gmail", authMiddleware, verifyGmail);

export default router; // ⭐ ИН ХАТ ХЕЛЕ МУҲИМ
