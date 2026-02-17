import { User } from "../models/user.model.js";
import { Post } from "../models/post.model.js";

export async function getStats() {
  const users = await User.countDocuments();
  const posts = await Post.countDocuments();

  return {
    users,
    posts,
  };
}

export async function verifyUser(userId) {
  await User.findByIdAndUpdate(userId, { verified: true });
}
