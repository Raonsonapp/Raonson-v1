import express from "express";
import {
  getNotifications,
  markSeen,
} from "../controllers/notification.controller.js";

const router = express.Router();

router.get("/", getNotifications);
router.post("/:id/seen", markSeen);

export default router;
