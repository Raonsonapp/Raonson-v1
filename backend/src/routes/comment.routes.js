import express from "express";
import { getComments, addComment } from "../controllers/comment.controller.js";

const router = express.Router();

router.get("/:reelId", getComments);
router.post("/:reelId", addComment);

export default router;
