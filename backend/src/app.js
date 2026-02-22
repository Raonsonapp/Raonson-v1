import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import { createRequire } from "module";
import { fileURLToPath } from "url";
import { dirname, join } from "path";

import { errorHandler } from "./core/errorHandler.js";
import { rateLimitMiddleware } from "./middleware/rateLimit.middleware.js";

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
import exploreRoutes from "./routes/explore.routes.js";
import uploadRoutes from "./routes/upload.routes.js";
import { unfollowUser } from "./controllers/follow.controller.js";
import { authMiddleware } from "./middleware/auth.middleware.js";

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const app = express();

// ================= CORE MIDDLEWARE =================
app.use(cors({ origin: "*", credentials: true }));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// ================= STATIC FILES =================
// Serve uploaded files (fallback when Cloudinary not configured)
app.use("/uploads", express.static(join(__dirname, "../../uploads")));

// ================= HEALTH =================
app.get("/", (req, res) => {
  res.json({
    status: "Raonson backend running ✅",
    uptime: process.uptime(),
    baseUrl: process.env.BASE_URL || "https://raonson-v1.onrender.com",
  });
});

app.get("/health", (req, res) => {
  res.json({ status: "ok", timestamp: new Date().toISOString() });
});

// ================= ROUTES =================
app.use("/auth", authRoutes);
app.use("/users", userRoutes);
app.use("/profile", profileRoutes);
app.use("/posts", rateLimitMiddleware(), postRoutes);
app.use("/comments", commentRoutes);
app.use("/likes", rateLimitMiddleware(), likeRoutes);
app.use("/follow", rateLimitMiddleware(), followRoutes);
app.post("/unfollow/:id", authMiddleware, unfollowUser);
app.use("/reels", reelRoutes);
app.use("/stories", storyRoutes);
app.use("/chat", chatRoutes);
app.use("/notifications", notificationRoutes);
app.use("/search", searchRoutes);
app.use("/explore", exploreRoutes);
app.use("/media", mediaRoutes);
app.use("/upload", uploadRoutes);
app.use("/admin", adminRoutes);

// ================= ERROR HANDLER =================
app.use(errorHandler);

export default app;
