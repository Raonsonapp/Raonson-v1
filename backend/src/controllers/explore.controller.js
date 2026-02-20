import { Post } from "../models/post.model.js";
import { Reel } from "../models/reel.model.js";

// 🔥 EXPLORE GRID (mixed content)
export async function exploreGrid(req, res) {
  const posts = await Post.find()
    .select("media user likes")
    .populate("user", "username avatar")
    .sort({ likes: -1 })
    .limit(40);

  const reels = await Reel.find()
    .select("video cover likes")
    .sort({ likes: -1 })
    .limit(20);

  res.json({
    posts,
    reels,
  });
}
