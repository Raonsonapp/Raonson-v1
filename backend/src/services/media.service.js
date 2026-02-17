import { Post } from "../models/post.model.js";
import { Reel } from "../models/reel.model.js";
import { Story } from "../models/story.model.js";

export async function getUserMedia(userId) {
  const posts = await Post.find({ user: userId });
  const reels = await Reel.find({ user: userId });
  const stories = await Story.find({ user: userId });

  return {
    posts,
    reels,
    stories,
  };
}
