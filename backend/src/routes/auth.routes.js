import express from "express";
import {
  sendOtp,
  verifyOtp,
  verifyGmail,
} from "../controllers/auth.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";

const router = express.Router();

/**
 * STEP 1: Send OTP to phone
 * body: { phone }
 */
router.post("/send-otp", sendOtp);

/**
 * STEP 2: Verify OTP code
 * body: { phone, code }
 * returns: tempToken
 */
router.post("/verify-otp", verifyOtp);

/**
 * STEP 3: Verify Gmail (final step)
 * headers: Authorization: Bearer tempToken
 * body: { email }
 */
router.post("/verify-gmail", authMiddleware, verifyGmail);

export default router;
