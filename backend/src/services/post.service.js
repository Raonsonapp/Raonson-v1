import { Post } from "../models/post.model.js";
import { User } from "../models/user.model.js";

export async function createPost(userId, caption, media) {
  const post = await Post.create({
    user: userId,
    caption,
    media,
  });

  await User.findByIdAndUpdate(userId, {
    $inc: { postsCount: 1 },
  });

  return post;
}

export async function getFeed() {
  return Post.find()
    .populate("user", "username avatar verified")
    .sort({ createdAt: -1 })
    .limit(50);
}
