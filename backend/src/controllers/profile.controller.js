import { User } from "../models/user.model.js";
import { Post } from "../models/post.model.js";

// GET PROFILE
export async function getProfile(req, res) {
  const user = await User.findById(req.params.id)
    .select("-password")
    .populate("followers following", "username avatar verified");

  const posts = await Post.find({ user: user._id })
    .sort({ createdAt: -1 })
    .select("media");

  res.json({
    user,
    posts,
    isFollowing: user.followers.includes(req.user._id),
  });
}

// FOLLOW / UNFOLLOW
export async function toggleFollow(req, res) {
  const targetId = req.params.id;
  const me = req.user._id;

  const target = await User.findById(targetId);
  const isFollowing = target.followers.includes(me);

  await User.findByIdAndUpdate(targetId, {
    [isFollowing ? "$pull" : "$addToSet"]: { followers: me },
  });

  await User.findByIdAndUpdate(me, {
    [isFollowing ? "$pull" : "$addToSet"]: { following: targetId },
  });

  res.json({ following: !isFollowing });
}
