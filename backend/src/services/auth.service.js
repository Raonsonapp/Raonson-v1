import jwt from "jsonwebtoken";
import { User } from "../models/user.model.js";
import { JWT_SECRET, JWT_EXPIRES } from "../config/jwt.config.js";

export function generateToken(user) {
  return jwt.sign(
    { id: user._id },
    JWT_SECRET,
    { expiresIn: JWT_EXPIRES }
  );
}

export async function getUserFromToken(token) {
  const decoded = jwt.verify(token, JWT_SECRET);
  return User.findById(decoded.id);
}
