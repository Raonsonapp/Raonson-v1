import { User } from "../models/user.model.js";
import { Post } from "../models/post.model.js";

export async function getProfile({ viewerId, username }) {
  const user = await User.findOne({ username }).select(
    "username avatar verified isPrivate followers following postsCount followersCount followingCount"
  );

  if (!user) throw new Error("User not found");

  const isOwner = viewerId.equals(user._id);
  const isFollowing = user.followers.includes(viewerId);
  const canViewPosts = !user.isPrivate || isOwner || isFollowing;

  let posts = [];
  if (canViewPosts) {
    posts = await Post.find({ user: user._id })
      .sort({ createdAt: -1 })
      .select("media createdAt");
  }

  return {
    user,
    isOwner,
    isFollowing,
    canViewPosts,
    posts,
  };
}
