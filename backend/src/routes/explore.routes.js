import express from "express";
import { exploreGrid } from "../controllers/explore.controller.js";

const router = express.Router();

router.get("/", exploreGrid);

export default router;
