import express from "express";
import authRoutes from "./routes/auth.routes.js";

const app = express();

app.use(express.json());

// routes
app.use("/auth", authRoutes);

// health check
app.get("/", (req, res) => {
  res.json({ status: "Raonson server is running" });
});

export default app;
