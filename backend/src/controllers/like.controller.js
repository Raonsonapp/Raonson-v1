import { Post } from "../models/post.model.js";

export async function toggleLike(req, res) {
  const post = await Post.findById(req.params.postId);

  const liked = post.likes.includes(req.user._id);

  await Post.findByIdAndUpdate(
    req.params.postId,
    liked
      ? { $pull: { likes: req.user._id } }
      : { $addToSet: { likes: req.user._id } }
  );

  res.json({ liked: !liked });
}
