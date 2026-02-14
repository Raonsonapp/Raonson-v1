import express from "express";
import {
  addComment,
  getComments,
} from "../controllers/comment.controller.js";

const router = express.Router();

router.post("/:id", addComment);
router.get("/:id", getComments);

export default router;
