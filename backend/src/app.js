import express from "express";
import cors from "cors";
import morgan from "morgan";

import { errorHandler } from "./core/errorHandler.js";
import { formatResponse } from "./core/responseFormatter.js";

// ROUTES
import authRoutes from "./routes/auth.routes.js";
import userRoutes from "./routes/user.routes.js";
import postRoutes from "./routes/post.routes.js";
import followRoutes from "./routes/follow.routes.js";
import storyRoutes from "./routes/story.routes.js";
import reelRoutes from "./routes/reel.routes.js";
import notificationRoutes from "./routes/notification.routes.js";
import profileRoutes from "./routes/profile.routes.js";
import searchRoutes from "./routes/search.routes.js";

const app = express();

// ================= MIDDLEWARE =================
app.use(cors());
app.use(express.json());
app.use(morgan("dev"));

// ================= HEALTH =================
app.get("/", (req, res) => {
  res.json(formatResponse(true, "Backend running", null));
});

// ================= ROUTES =================
app.use("/auth", authRoutes);
app.use("/users", userRoutes);
app.use("/posts", postRoutes);
app.use("/follow", followRoutes);
app.use("/stories", storyRoutes);
app.use("/reels", reelRoutes);
app.use("/notifications", notificationRoutes);
app.use("/profile", profileRoutes);
app.use("/search", searchRoutes);

// ================= ERROR =================
app.use(errorHandler);

export default app;
