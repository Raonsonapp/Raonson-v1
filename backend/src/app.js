import express from "express";
import { connectDB } from "./config/db.js";
import authRoutes from "./routes/auth.routes.js";
import profileRoutes from "./routes/profile.routes.js";
import postRoutes from "./routes/post.routes.js";
import likeRoutes from "./routes/like.routes.js";

const app = express();

connectDB();

app.use(express.json());

app.use("/auth", authRoutes);
app.use("/profile", profileRoutes);
app.use("/posts", postRoutes);
app.use("/likes", likeRoutes);

app.get("/", (req, res) => {
  res.json({ status: "Raonson server is running" });
});

export default app;
