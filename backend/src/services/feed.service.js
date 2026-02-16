import { Follow } from "../models/follow.model.js";
import { Post } from "../models/post.model.js";

export async function getHomeFeed(userId) {
  const following = await Follow.find({
    from: userId,
    status: "accepted",
  }).select("to");

  const ids = following.map((f) => f.to);
  ids.push(userId);

  return Post.find({ user: { $in: ids } })
    .populate("user", "username avatar verified")
    .sort({ createdAt: -1 })
    .limit(50);
                            }
