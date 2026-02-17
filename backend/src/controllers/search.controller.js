import { User } from "../models/user.model.js";
import { Post } from "../models/post.model.js";

export async function search(req, res) {
  const q = req.query.q;

  const users = await User.find({
    username: { $regex: q, $options: "i" },
  }).select("username avatar verified");

  const posts = await Post.find({
    caption: { $regex: q, $options: "i" },
  }).limit(20);

  res.json({ users, posts });
}
