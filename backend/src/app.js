// backend/src/app.js
import express from "express";
import cors from "cors";

// ROUTES
import authRoutes from "./routes/auth.routes.js";
import postRoutes from "./routes/post.routes.js";
import commentRoutes from "./routes/comment.routes.js";
import followRoutes from "./routes/follow.routes.js";
import reelRoutes from "./routes/reel.routes.js";
import storyRoutes from "./routes/story.routes.js";
import notificationRoutes from "./routes/notification.routes.js";

const app = express();

// ================= MIDDLEWARE =================
app.use(cors());
app.use(express.json());

// ================= HEALTH CHECK =================
app.get("/", (req, res) => {
  res.json({ status: "Raonson backend running ✅" });
});

// ================= ROUTES =================
app.use("/auth", authRoutes);
app.use("/posts", postRoutes);
app.use("/comments", commentRoutes);
app.use("/follow", followRoutes);
app.use("/reels", reelRoutes);
app.use("/stories", storyRoutes);
app.use("/notifications", notificationRoutes);

export default app;
