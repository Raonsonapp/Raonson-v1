import { Post } from "../models/post.model.js";
import { Follow } from "../models/follow.model.js";

// ================= FEED =================
export async function getFeed(req, res) {
  const userId = req.user._id;
  const page = Math.max(1, Number(req.query.page || 1));
  const limit = Math.min(20, Number(req.query.limit || 10));
  const skip = (page - 1) * limit;

  // 🔹 users I follow
  const following = await Follow.find({ follower: userId })
    .select("following");

  const followingIds = following.map(f => f.following);

  // 🔹 posts from following
  const posts = await Post.find({ user: { $in: followingIds } })
    .populate("user", "username avatar verified")
    .sort({ createdAt: -1 })
    .skip(skip)
    .limit(limit + 1);

  const hasMore = posts.length > limit;
  if (hasMore) posts.pop();

  const items = posts.map(p => ({
    _id: p._id,
    user: p.user,
    caption: p.caption,
    media: p.media,
    likesCount: p.likes.length,
    commentsCount: p.commentsCount || 0,
    liked: p.likes.includes(userId),
    saved: p.saves.includes(userId),
    createdAt: p.createdAt,
  }));

  res.json({
    items,
    nextPage: page + 1,
    hasMore,
  });
}

// ================= LIKE =================
export async function toggleLike(req, res) {
  const userId = req.user._id;
  const post = await Post.findById(req.params.id);

  const liked = post.likes.includes(userId);

  await Post.findByIdAndUpdate(
    post._id,
    liked
      ? { $pull: { likes: userId } }
      : { $addToSet: { likes: userId } }
  );

  res.json({ liked: !liked });
}

// ================= SAVE =================
export async function toggleSave(req, res) {
  const userId = req.user._id;
  const post = await Post.findById(req.params.id);

  const saved = post.saves.includes(userId);

  await Post.findByIdAndUpdate(
    post._id,
    saved
      ? { $pull: { saves: userId } }
      : { $addToSet: { saves: userId } }
  );

  res.json({ saved: !saved });
}
