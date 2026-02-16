import express from "express";
import { searchAll } from "../controllers/search.controller.js";

const router = express.Router();

// /search?q=raon
router.get("/", searchAll);

export default router;
