import express from "express";
import {
  searchUsers,
  searchPosts,
  exploreReels,
} from "../controllers/search.controller.js";

const router = express.Router();

router.get("/users", searchUsers);
router.get("/posts", searchPosts);
router.get("/reels", exploreReels);

export default router;
