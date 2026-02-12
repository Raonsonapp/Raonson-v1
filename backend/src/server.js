import express from "express";
import cors from "cors";
import { v4 as uuid } from "uuid";
import app from "./app.js";

const app = express();

app.use(cors());
app.use(express.json());

/* ================== DATA (MVP – in memory) ================== */
const users = [
  {
    id: "u1",
    username: "raonson",
    followers: 0,
    following: 0,
    avatar: "https://i.pravatar.cc/150?img=3",
  },
];

const posts = [
  {
    id: "p1",
    userId: "u1",
    image: "https://picsum.photos/500/700",
    caption: "First post on Raonson 🚀",
    likes: 0,
    saved: 0,
  },
];

const comments = {
  p1: [],
};

/* ================== ROUTES ================== */
app.get("/", (req, res) => {
  res.json({ status: "Raonson backend running ✅" });
});

app.get("/health", (req, res) => {
  res.json({ status: "OK" });
});

/* POSTS */
app.get("/posts", (req, res) => {
  res.json(posts);
});

app.post("/posts", (req, res) => {
  const { userId, image, caption } = req.body;

  const post = {
    id: uuid(),
    userId,
    image,
    caption,
    likes: 0,
    saved: 0,
  };

  posts.unshift(post);
  comments[post.id] = [];
  res.json(post);
});

/* LIKES */
app.post("/likes/:postId", (req, res) => {
  const post = posts.find((p) => p.id === req.params.postId);
  if (!post) return res.status(404).json({ error: "Post not found" });

  post.likes += 1;
  res.json({ likes: post.likes });
});

/* SAVE */
app.post("/save/:postId", (req, res) => {
  const post = posts.find((p) => p.id === req.params.postId);
  if (!post) return res.status(404).json({ error: "Post not found" });

  post.saved += 1;
  res.json({ saved: post.saved });
});

/* COMMENTS */
app.get("/comments/:postId", (req, res) => {
  res.json(comments[req.params.postId] || []);
});

app.post("/comments/:postId", (req, res) => {
  const { text } = req.body;

  const comment = {
    id: uuid(),
    text,
    createdAt: new Date(),
  };

  if (!comments[req.params.postId]) {
    comments[req.params.postId] = [];
  }

  comments[req.params.postId].push(comment);
  res.json(comment);
});

/* ================== START ================== */
const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log("🚀 Raonson backend running on port", PORT);
});
