import { User } from "../models/user.model.js";
import { Post } from "../models/post.model.js";

export async function getProfile(username) {
  const user = await User.findOne({ username })
    .select("username avatar verified isPrivate followersCount followingCount postsCount");

  if (!user) return null;

  const posts = await Post.find({ user: user._id })
    .sort({ createdAt: -1 })
    .limit(12);

  return { user, posts };
}
