import { Post } from "../models/post.model.js";
import { User } from "../models/user.model.js";

export async function getUserFeed({
  userId,
  limit = 20,
  cursor,
}) {
  const user = await User.findById(userId).select("following");
  if (!user) throw new Error("User not found");

  const feedUsers = [userId, ...user.following];

  const query = {
    user: { $in: feedUsers },
  };

  if (cursor) {
    query.createdAt = { $lt: new Date(cursor) };
  }

  const posts = await Post.find(query)
    .populate("user", "username avatar verified")
    .sort({ createdAt: -1 })
    .limit(limit);

  return posts;
}
