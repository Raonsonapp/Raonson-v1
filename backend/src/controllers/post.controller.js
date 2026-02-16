import { Post } from "../models/post.model.js";
import { User } from "../models/user.model.js";
import { getHomeFeed } from "../services/feed.service.js";

// CREATE POST
export async function createPost(req, res) {
  const { caption, media } = req.body;

  const post = await Post.create({
    user: req.user._id,
    caption,
    media,
  });

  await User.findByIdAndUpdate(req.user._id, {
    $inc: { postsCount: 1 },
  });

  res.json(post);
}

// HOME FEED (FILTERED)
export async function getFeed(req, res) {
  const posts = await getHomeFeed(req.user._id);
  res.json(posts);
}
