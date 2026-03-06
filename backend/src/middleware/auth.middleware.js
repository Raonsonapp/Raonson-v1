import jwt from "jsonwebtoken";
import mongoose from "mongoose";

const JWT_SECRET = process.env.JWT_SECRET || "RAONSON_SECRET";

export const authMiddleware = (req, res, next) => {
  const auth = req.headers.authorization;
  if (!auth) return res.status(401).json({ message: "No token" });

  const token = auth.split(" ")[1];
  if (!token) return res.status(401).json({ message: "No token" });

  try {
    const decoded = jwt.verify(token, JWT_SECRET);

    // Convert string id to ObjectId so DB queries work correctly
    const objectId = new mongoose.Types.ObjectId(decoded.id);

    req.userId = decoded.id;
    req.user = {
      id:   decoded.id,
      _id:  objectId,   // ← ObjectId, not string
      role: decoded.role,
    };

    next();
  } catch {
    res.status(401).json({ message: "Invalid token" });
  }
};
