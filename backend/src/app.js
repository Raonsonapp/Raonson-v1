import express from "express";

const app = express();

// middleware
app.use(express.json());

// test route
app.get("/", (req, res) => {
  res.json({ status: "Raonson server is running" });
});

export default app;
