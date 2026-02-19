import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { User } from "../models/user.model.js";

const JWT_SECRET = process.env.JWT_SECRET || "RAONSON_SECRET";
const JWT_REFRESH_SECRET =
  process.env.JWT_REFRESH_SECRET || "RAONSON_REFRESH_SECRET";

/* ================= REGISTER ================= */
export const register = async (req, res) => {
  try {
    const username = req.body.username?.trim();
    const email = req.body.email?.trim().toLowerCase();
    const password = req.body.password;

    if (!username || !email || !password) {
      return res.status(400).json({ message: "Missing fields" });
    }

    const exists = await User.findOne({
      $or: [{ email }, { username }],
    });

    if (exists) {
      return res
        .status(409)
        .json({ message: "Username or email already taken" });
    }

    const hashed = await bcrypt.hash(password, 10);

    const user = await User.create({
      username,
      email,
      password: hashed,
    });

    return res.status(201).json({
      success: true,
      user: {
        id: user._id,
        username: user.username,
        email: user.email,
      },
    });
  } catch (e) {
    // Mongo duplicate index
    if (e?.code === 11000) {
      return res
        .status(409)
        .json({ message: "Username or email already taken" });
    }

    console.error("REGISTER ERROR:", e);
    return res.status(500).json({ message: "Register failed" });
  }
};

/* ================= LOGIN ================= */
export const login = async (req, res) => {
  try {
    const email = req.body.email?.trim().toLowerCase();
    const password = req.body.password;

    if (!email || !password) {
      return res.status(400).json({ message: "Missing fields" });
    }

    const user = await User.findOne({ email });
    if (!user) {
      return res
        .status(401)
        .json({ message: "Invalid email or password" });
    }

    const ok = await bcrypt.compare(password, user.password);
    if (!ok) {
      return res
        .status(401)
        .json({ message: "Invalid email or password" });
    }

    const accessToken = jwt.sign(
      { id: user._id },
      JWT_SECRET,
      { expiresIn: "7d" }
    );

    const refreshToken = jwt.sign(
      { id: user._id },
      JWT_REFRESH_SECRET,
      { expiresIn: "30d" }
    );

    return res.json({
      accessToken,
      refreshToken,
      user: {
        id: user._id,
        username: user.username,
        email: user.email,
      },
    });
  } catch (e) {
    console.error("LOGIN ERROR:", e);
    return res.status(500).json({ message: "Login failed" });
  }
};

/* ================= REFRESH ================= */
export const refreshToken = async (req, res) => {
  try {
    const token = req.body.refreshToken;
    if (!token) {
      return res.status(401).json({ message: "No refresh token" });
    }

    const payload = jwt.verify(token, JWT_REFRESH_SECRET);

    const accessToken = jwt.sign(
      { id: payload.id },
      JWT_SECRET,
      { expiresIn: "7d" }
    );

    return res.json({ accessToken });
  } catch {
    return res.status(403).json({ message: "Invalid refresh token" });
  }
};

/* ================= LOGOUT ================= */
export const logout = async (_req, res) => {
  return res.json({ success: true });
};
