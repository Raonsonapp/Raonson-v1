import express from "express";
import { addComment, getComments } from "../controllers/comment.controller.js";

const router = express.Router();

router.get("/reels/:targetId", getComments);
router.post("/reels/:targetId", addComment);

export default router;
