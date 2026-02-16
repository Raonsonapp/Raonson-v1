import jwt from "jsonwebtoken";
import { ENV } from "../config/env.js";
import { User } from "../models/user.model.js";

export async function authMiddleware(req, res, next) {
  try {
    const token = req.headers.authorization?.replace("Bearer ", "");
    if (!token) return res.sendStatus(401);

    const payload = jwt.verify(token, ENV.JWT_SECRET);
    const user = await User.findById(payload.id);

    if (!user) return res.sendStatus(401);

    req.user = user;
    next();
  } catch {
    res.sendStatus(401);
  }
}
