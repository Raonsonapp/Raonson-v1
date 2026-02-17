import { Post } from "../models/post.model.js";

export async function togglePostLike(userId, postId) {
  const post = await Post.findById(postId);

  if (!post) return null;

  const liked = post.likes.includes(userId);

  await Post.findByIdAndUpdate(
    postId,
    liked
      ? { $pull: { likes: userId } }
      : { $addToSet: { likes: userId } }
  );

  return { liked: !liked };
}
