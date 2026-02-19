import jwt from "jsonwebtoken";

const JWT_SECRET = process.env.JWT_SECRET || "RAONSON_SECRET";

export const authMiddleware = (req, res, next) => {
  const auth = req.headers.authorization;
  if (!auth) return res.status(401).json({ message: "No token" });

  const token = auth.split(" ")[1];
  if (!token) return res.status(401).json({ message: "No token" });

  try {
    const decoded = jwt.verify(token, JWT_SECRET);

    // ✅ Backward + forward compatibility across controllers
    req.userId = decoded.id;
    req.user = {
      id: decoded.id,
      _id: decoded.id,
      role: decoded.role,
    };

    next();
  } catch {
    res.status(401).json({ message: "Invalid token" });
  }
};
