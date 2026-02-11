import express from "express";
import cors from "cors";
import apiRoutes from "./routes/index.js";

const app = express();

app.use(cors());
app.use(express.json());

app.get("/", (req, res) => {
  res.json({ status: "Raonson server is running" });
});

app.use("/api", apiRoutes);

export default app;
