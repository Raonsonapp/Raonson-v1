import express from "express";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { User } from "../models/user.model.js";
import { ENV } from "../config/env.js";

const router = express.Router();

// REGISTER
router.post("/register", async (req, res) => {
  const { username, email, password } = req.body;

  const hash = await bcrypt.hash(password, 10);

  const user = await User.create({
    username,
    email,
    passwordHash: hash,
  });

  const token = jwt.sign({ id: user._id }, ENV.JWT_SECRET);

  res.json({ token, user });
});

// LOGIN
router.post("/login", async (req, res) => {
  const { email, password } = req.body;

  const user = await User.findOne({ email });
  if (!user) return res.sendStatus(401);

  const ok = await bcrypt.compare(password, user.passwordHash);
  if (!ok) return res.sendStatus(401);

  const token = jwt.sign({ id: user._id }, ENV.JWT_SECRET);

  res.json({ token, user });
});

export default router;
