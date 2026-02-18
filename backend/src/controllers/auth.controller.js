import bcrypt from "bcryptjs";
import { User } from "../models/user.model.js";
import {
  signAccessToken,
  signRefreshToken,
} from "../config/jwt.config.js";

// REGISTER
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

  const accessToken = signAccessToken({ id: user._id });
  const refreshToken = signRefreshToken({ id: user._id });

  res.json({
    user,
    accessToken,
    refreshToken,
  });
}

// LOGIN
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

  const accessToken = signAccessToken({ id: user._id });
  const refreshToken = signRefreshToken({ id: user._id });

  res.json({
    user,
    accessToken,
    refreshToken,
  });
}

// REFRESH TOKEN
export async function refreshToken(req, res) {
  const accessToken = signAccessToken({ id: req.user.id });
  res.json({ accessToken });
}

// LOGOUT
export async function logout(req, res) {
  res.json({ success: true });
    }
// REGISTER
export async function register(req, res) {
  const { username, email, password } = req.body; // ⬅ ИЛОВА

  // ⬇ ИЛОВА: санҷиши email
  if (!email) {
    return res.status(400).json({ message: "Email is required" });
  }

  const exists = await User.findOne({
    $or: [{ username }, { email }], // ⬅ ИЛОВА
  });

  if (exists) {
    return res
      .status(400)
      .json({ message: "Username or email already taken" });
  }

  const hash = await bcrypt.hash(password, 10);

  const user = await User.create({
    username,
    email,            // ⬅ ИЛОВА
    password: hash,
  });

  const accessToken = signAccessToken({ id: user._id });
  const refreshToken = signRefreshToken({ id: user._id });

  res.json({
    user,
    accessToken,
    refreshToken,
  });
    }
