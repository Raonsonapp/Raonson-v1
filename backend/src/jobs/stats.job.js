import { User } from "../models/user.model.js";
import { Post } from "../models/post.model.js";
import { Reel } from "../models/reel.model.js";

export async function runStatsJob() {
  const users = await User.countDocuments();
  const posts = await Post.countDocuments();
  const reels = await Reel.countDocuments();

  const totalLikes = await Post.aggregate([
    { $project: { likesCount: { $size: "$likes" } } },
    { $group: { _id: null, total: { $sum: "$likesCount" } } },
  ]);

  return {
    users,
    posts,
    reels,
    totalLikes: totalLikes[0]?.total || 0,
    generatedAt: new Date(),
  };
}
