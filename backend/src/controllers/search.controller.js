import { User } from "../models/user.model.js";
import { Post } from "../models/post.model.js";
import { Reel } from "../models/reel.model.js";

// 🔍 SEARCH USERS
export async function searchUsers(req, res) {
  const q = req.query.q || "";

  const users = await User.find({
    username: { $regex: q, $options: "i" },
  })
    .select("username avatar verified")
    .limit(20);

  res.json(users);
}

// 🔍 SEARCH POSTS (hashtags / caption)
export async function searchPosts(req, res) {
  const q = req.query.q || "";

  const posts = await Post.find({
    caption: { $regex: q, $options: "i" },
  })
    .populate("user", "username avatar verified")
    .sort({ createdAt: -1 })
    .limit(20);

  res.json(posts);
}

// 🔥 EXPLORE REELS (TRENDING)
export async function exploreReels(req, res) {
  const reels = await Reel.find()
    .sort({ views: -1, likes: -1 })
    .limit(30);

  res.json(reels);
}
