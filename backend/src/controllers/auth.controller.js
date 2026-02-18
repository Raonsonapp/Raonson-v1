import bcrypt from "bcryptjs";
import { User } from "../models/user.model.js";
import {
  signAccessToken,
  signRefreshToken,
} from "../config/jwt.config.js";

// =======================
// REGISTER
// =======================
export async function register(req, res) {
  try {
    const { username, email, password } = req.body;

    // validation
    if (!username || !email || !password) {
      return res
        .status(400)
        .json({ message: "Username, email and password are required" });
    }

    // check existing user
    const exists = await User.findOne({
      $or: [{ username }, { email }],
    });

    if (exists) {
      return res
        .status(400)
        .json({ message: "Username or email already taken" });
    }

    // hash password
    const hash = await bcrypt.hash(password, 10);

    // create user
    const user = await User.create({
      username,
      email,
      password: hash,
    });

    // tokens
    const accessToken = signAccessToken({ id: user._id });
    const refreshToken = signRefreshToken({ id: user._id });

    return res.json({
      user,
      accessToken,
      refreshToken,
    });
  } catch (err) {
    console.error("REGISTER ERROR:", err);
    return res.status(500).json({ message: "Server error" });
  }
}

// =======================
// LOGIN (username OR email)
// =======================
export async function login(req, res) {
  try {
    const { username, email, password } = req.body;

    if ((!username && !email) || !password) {
      return res
        .status(400)
        .json({ message: "Credentials missing" });
    }

    const user = await User.findOne({
      $or: [{ username }, { email }],
    });

    if (!user) {
      return res.status(401).json({ message: "Invalid credentials" });
    }

    const ok = await bcrypt.compare(password, user.password);
    if (!ok) {
      return res.status(401).json({ message: "Invalid credentials" });
    }

    const accessToken = signAccessToken({ id: user._id });
    const refreshToken = signRefreshToken({ id: user._id });

    return res.json({
      user,
      accessToken,
      refreshToken,
    });
  } catch (err) {
    console.error("LOGIN ERROR:", err);
    return res.status(500).json({ message: "Server error" });
  }
}

// =======================
// REFRESH TOKEN
// =======================
export async function refreshToken(req, res) {
  const accessToken = signAccessToken({ id: req.user.id });
  return res.json({ accessToken });
}

// =======================
// LOGOUT
// =======================
export async function logout(req, res) {
  return res.json({ success: true });
        }
