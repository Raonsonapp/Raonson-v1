import express from "express";
import cors from "cors";
import dotenv from "dotenv";

import { errorHandler } from "./core/errorHandler.js";
import { rateLimitMiddleware } from "./middlewares/rateLimit.middleware.js";

// ROUTES
import authRoutes from "./routes/auth.routes.js";
import userRoutes from "./routes/user.routes.js";
import profileRoutes from "./routes/profile.routes.js";
import postRoutes from "./routes/post.routes.js";
import commentRoutes from "./routes/comment.routes.js";
import likeRoutes from "./routes/like.routes.js";
import followRoutes from "./routes/follow.routes.js";
import reelRoutes from "./routes/reel.routes.js";
import storyRoutes from "./routes/story.routes.js";
import chatRoutes from "./routes/chat.routes.js";
import notificationRoutes from "./routes/notification.routes.js";
import searchRoutes from "./routes/search.routes.js";
import mediaRoutes from "./routes/media.routes.js";
import adminRoutes from "./routes/admin.routes.js";

dotenv.config();

const app = express();

// ================= CORE MIDDLEWARE =================
app.use(cors());
app.use(express.json({ limit: "50mb" }));
app.use(express.urlencoded({ extended: true }));
app.use(rateLimitMiddleware);

// ================= HEALTH =================
app.get("/", (req, res) => {
  res.json({
    status: "Raonson backend running",
    uptime: process.uptime(),
    baseUrl: process.env.BASE_URL || "https://raonson-v1.onrender.com"
  });
});

// ================= ROUTES =================
app.use("/auth", authRoutes);
app.use("/users", userRoutes);
app.use("/profile", profileRoutes);
app.use("/posts", postRoutes);
app.use("/comments", commentRoutes);
app.use("/likes", likeRoutes);
app.use("/follow", followRoutes);
app.use("/reels", reelRoutes);
app.use("/stories", storyRoutes);
app.use("/chat", chatRoutes);
app.use("/notifications", notificationRoutes);
app.use("/search", searchRoutes);
app.use("/media", mediaRoutes);
app.use("/admin", adminRoutes);

// ================= ERROR HANDLER =================
app.use(errorHandler);

export default app;
