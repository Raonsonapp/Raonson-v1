import jwt from "jsonwebtoken";
import bcrypt from "bcryptjs";
import { User } from "../models/user.model.js";
import { jwtConfig } from "../config/jwt.config.js";

function generateToken(user) {
  return jwt.sign(
    { id: user._id },
    jwtConfig.secret,
    { expiresIn: jwtConfig.expiresIn }
  );
}

export async function register(req, res) {
  const { username, password } = req.body;

  const exists = await User.findOne({ username });
  if (exists) {
    return res.status(400).json({ message: "Username already taken" });
  }

  const hash = await bcrypt.hash(password, 10);

  const user = await User.create({
    username,
    password: hash,
  });

  const token = generateToken(user);

  res.json({ user, token });
}

export async function login(req, res) {
  const { username, password } = req.body;

  const user = await User.findOne({ username });
  if (!user) {
    return res.status(401).json({ message: "Invalid credentials" });
  }

  const ok = await bcrypt.compare(password, user.password);
  if (!ok) {
    return res.status(401).json({ message: "Invalid credentials" });
  }

  const token = generateToken(user);

  res.json({ user, token });
}

export async function refreshToken(req, res) {
  const token = generateToken(req.user);
  res.json({ token });
}

export async function logout(req, res) {
  res.json({ success: true });
    }
