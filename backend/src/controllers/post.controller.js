import { posts } from "../data/posts.store.js";
import { addNotification } from "./notification.controller.js";

// GET FEED
export const getFeed = (req, res) => {
  res.json(posts);
};

// CREATE POST
export const createPost = (req, res) => {
  const { user, caption, media } = req.body;

  const post = {
    id: Date.now().toString(),
    user,
    caption,
    media, // [{url,type}]
    likes: 0,
    comments: [],
    createdAt: new Date(),
  };

  posts.unshift(post);
  res.json(post);
};

// LIKE POST
export const likePost = (req, res) => {
  const { id } = req.params;
  const { user } = req.body;

  const post = posts.find(p => p.id === id);
  if (!post) return res.status(404).json({ error: "Post not found" });

  post.likes += 1;

  if (post.user !== user) {
    addNotification({
      to: post.user,
      from: user,
      type: "like",
      postId: post.id,
    });
  }

  res.json({ likes: post.likes });
};
