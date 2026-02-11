import express from "express";
import { registerStep1 } from "../controllers/auth.controller.js";

const router = express.Router();

// Регистрация – Қадам 1
router.post("/register/step1", registerStep1);

export default router;
