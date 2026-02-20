import express from "express";
import authRoutes from "./auth.routes.js";

const router = express.Router();

router.get("/", (req, res) => {
  res.json({ api: "Raonson API working" });
});

router.use("/auth", authRoutes);

export default router;
