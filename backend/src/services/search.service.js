import { User } from "../models/user.model.js";
import { Post } from "../models/post.model.js";

export async function searchAll(query) {
  const regex = new RegExp(query, "i");

  const users = await User.find({ username: regex })
    .select("username avatar verified")
    .limit(20);

  const posts = await Post.find({ caption: regex })
    .populate("user", "username avatar")
    .limit(20);

  return { users, posts };
}
