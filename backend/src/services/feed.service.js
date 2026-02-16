import { Post } from "../models/post.model.js";
import { User } from "../models/user.model.js";

export async function getPersonalFeed({
  userId,
  page = 1,
  limit = 10,
}) {
  const me = await User.findById(userId).select("following");

  const visibleUsers = [
    userId,
    ...me.following,
  ];

  const posts = await Post.find({
    user: { $in: visibleUsers },
  })
    .populate("user", "username avatar verified")
    .sort({ createdAt: -1 })
    .skip((page - 1) * limit)
    .limit(limit);

  return posts;
}
