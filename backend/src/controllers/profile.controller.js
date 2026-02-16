import { User } from "../models/user.model.js";
import { Post } from "../models/post.model.js";
import { Reel } from "../models/reel.model.js";

// GET PROFILE (Instagram-style)
export async function getProfile(req, res) {
  const { username } = req.params;

  const user = await User.findOne({ username })
    .select("username avatar bio verified followers following postsCount");

  if (!user) {
    return res.status(404).json({ error: "User not found" });
  }

  const posts = await Post.find({ user: user._id })
    .select("media likes")
    .sort({ createdAt: -1 });

  const reels = await Reel.find({ user: user._id })
    .select("video cover likes")
    .sort({ createdAt: -1 });

  res.json({
    user,
    posts,
    reels,
  });
}
