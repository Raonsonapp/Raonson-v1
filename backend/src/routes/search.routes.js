import express from "express";
import { search } from "../controllers/search.controller.js";
import { authMiddleware } from "../middlewares/auth.middleware.js";

const router = express.Router();

router.get("/", authMiddleware, search);

export default router;
