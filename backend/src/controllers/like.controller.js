import Like from "../models/like.model.js";
import Post from "../models/post.model.js";

// LIKE / UNLIKE (toggle)
export const toggleLike = async (req, res) => {
  const { postId } = req.params;
  const userId = req.user.id;

  const existing = await Like.findOne({ userId, postId });

  if (existing) {
    await existing.deleteOne();
    await Post.findByIdAndUpdate(postId, { $inc: { likesCount: -1 } });
    return res.json({ liked: false });
  } else {
    await Like.create({ userId, postId });
    await Post.findByIdAndUpdate(postId, { $inc: { likesCount: 1 } });
    return res.json({ liked: true });
  }
};
