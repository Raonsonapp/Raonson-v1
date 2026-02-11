import express from "express";
import { connectDB } from "./config/db.js";
import authRoutes from "./routes/auth.routes.js";
import profileRoutes from "./routes/profile.routes.js";
import postRoutes from "./routes/post.routes.js";
import likeRoutes from "./routes/like.routes.js";
import commentRoutes from "./routes/comment.routes.js";
import followRoutes from "./routes/follow.routes.js";
import path from "path";
import uploadRoutes from "./routes/upload.routes.js";

const app = express();

connectDB();

app.use(express.json());
app.use("/uploads", express.static(path.join("src/uploads")));

app.use("/auth", authRoutes);
app.use("/profile", profileRoutes);
app.use("/posts", postRoutes);
app.use("/likes", likeRoutes);
app.use("/comments", commentRoutes);
app.use("/follow", followRoutes);
app.use("/upload", uploadRoutes);

app.get("/", (req, res) => {
  res.json({ status: "Raonson server is running" });
});

export default app;
