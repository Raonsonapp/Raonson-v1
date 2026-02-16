import express from "express";
import cors from "cors";
import authRoutes from "./routes/auth.routes.js";

const app = express();

app.use(cors());
app.use(express.json());

app.get("/", (_, res) => {
  res.json({ status: "Raonson API running 🚀" });
});

app.use("/auth", authRoutes);

export default app;
