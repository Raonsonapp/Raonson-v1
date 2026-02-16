import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { User } from "../models/user.model.js";
import { jwtConfig } from "../config/jwt.config.js";

export async function registerUser({ username, email, password }) {
  const exists = await User.findOne({ username });
  if (exists) {
    throw new Error("Username already taken");
  }

  const hash = await bcrypt.hash(password, 10);

  const user = await User.create({
    username,
    email,
    password: hash,
  });

  return user;
}

export async function loginUser({ username, password }) {
  const user = await User.findOne({ username }).select("+password");
  if (!user) throw new Error("Invalid credentials");

  const ok = await bcrypt.compare(password, user.password);
  if (!ok) throw new Error("Invalid credentials");

  const token = jwt.sign(
    { id: user._id },
    jwtConfig.secret,
    { expiresIn: jwtConfig.expiresIn }
  );

  return { user, token };
    }
