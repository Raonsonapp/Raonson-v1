import { User } from "../models/user.model.js";
import { Post } from "../models/post.model.js";

export async function searchAll(req, res) {
  const q = req.query.q?.trim();

  if (!q) {
    return res.json({ users: [], posts: [] });
  }

  const regex = new RegExp(q, "i");

  const users = await User.find({
    username: regex,
  })
    .select("username avatar verified")
    .limit(20);

  const posts = await Post.find({
    caption: regex,
  })
    .populate("user", "username avatar verified")
    .sort({ createdAt: -1 })
    .limit(20);

  res.json({ users, posts });
}
