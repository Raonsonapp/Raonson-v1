import { Post } from "../models/post.model.js";
import { User } from "../models/user.model.js";
import { getPersonalFeed } from "../services/feed.service.js";

// ================= CREATE POST =================
export async function createPost(req, res, next) {
  try {
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
  } catch (e) {
    next(e);
  }
}

// ================= PERSONAL FEED =================
export async function getFeed(req, res, next) {
  try {
    const page = Number(req.query.page || 1);
    const limit = Number(req.query.limit || 10);

    const posts = await getPersonalFeed({
      userId: req.user._id,
      page,
      limit,
    });

    res.json(posts);
  } catch (e) {
    next(e);
  }
}

// ================= LIKE =================
export async function toggleLike(req, res, next) {
  try {
    const post = await Post.findById(req.params.id);

    const liked = post.likes.includes(req.user._id);

    await Post.findByIdAndUpdate(req.params.id, liked
      ? { $pull: { likes: req.user._id } }
      : { $addToSet: { likes: req.user._id } }
    );

    res.json({ liked: !liked });
  } catch (e) {
    next(e);
  }
}

// ================= SAVE =================
export async function toggleSave(req, res, next) {
  try {
    const post = await Post.findById(req.params.id);

    const saved = post.saves.includes(req.user._id);

    await Post.findByIdAndUpdate(req.params.id, saved
      ? { $pull: { saves: req.user._id } }
      : { $addToSet: { saves: req.user._id } }
    );

    res.json({ saved: !saved });
  } catch (e) {
    next(e);
  }
                                     }
