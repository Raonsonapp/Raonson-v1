import { Post } from "../models/post.model.js";
import { User } from "../models/user.model.js";

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

export async function getFeed(req, res) {
  const posts = await Post.find()
    .populate("user", "username avatar verified")
    .sort({ createdAt: -1 })
    .limit(50);

  res.json(posts);
}

export async function toggleLike(req, res) {
  const post = await Post.findById(req.params.id);

  const liked = post.likes.includes(req.user._id);

  await Post.findByIdAndUpdate(
    req.params.id,
    liked
      ? { $pull: { likes: req.user._id } }
      : { $addToSet: { likes: req.user._id } }
  );

  res.json({ liked: !liked });
}

export async function toggleSave(req, res) {
  const post = await Post.findById(req.params.id);

  const saved = post.saves.includes(req.user._id);

  await Post.findByIdAndUpdate(
    req.params.id,
    saved
      ? { $pull: { saves: req.user._id } }
      : { $addToSet: { saves: req.user._id } }
  );

  res.json({ saved: !saved });
}
