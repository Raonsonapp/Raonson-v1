import jwt from "jsonwebtoken";
import { jwtConfig } from "../config/jwt.config.js";
import { User } from "../models/user.model.js";

export async function authMiddleware(req, res, next) {
  try {
    const header = req.headers.authorization;
    if (!header) throw new Error("No token");

    const token = header.split(" ")[1];
    const decoded = jwt.verify(token, jwtConfig.secret);

    const user = await User.findById(decoded.id);
    if (!user) throw new Error("User not found");

    req.user = user;
    next();
  } catch (e) {
    res.status(401).json({ success: false, message: "Unauthorized" });
  }
}
