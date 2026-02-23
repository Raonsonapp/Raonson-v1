import { Post } from "../models/post.model.js";
import { User } from "../models/user.model.js";
import { Comment } from "../models/comment.model.js";

// Helper: format post with isLiked/isSaved for current user
function formatPost(post, userId) {
  const p = post.toObject();
  p.likesCount = p.likes?.length ?? 0;
  p.liked = userId ? p.likes?.some(id => id.toString() === userId.toString()) : false;
  p.saved = userId ? p.saves?.some(id => id.toString() === userId.toString()) : false;
  return p;
}

// CREATE POST
export async function createPost(req, res) {
  try {
    const { caption, media } = req.body;

    if (!media || !Array.isArray(media) || media.length === 0) {
      return res.status(400).json({ message: "At least one media item required" });
    }

    const post = await Post.create({
      user: req.user._id,
      caption: caption || "",
      media,
    });

    await User.findByIdAndUpdate(req.user._id, { $inc: { postsCount: 1 } });

    const populated = await post.populate("user", "username avatar verified");
    res.status(201).json(formatPost(populated, req.user._id));
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Create post failed" });
  }
}

// GET FEED - with isLiked/isSaved per user
export async function getFeed(req, res) {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const skip = (page - 1) * limit;

    const posts = await Post.find()
      .populate("user", "username avatar verified")
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit);

    const userId = req.user._id;
    const formatted = posts.map(p => formatPost(p, userId));

    res.json({ posts: formatted, page, limit });
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Get feed failed" });
  }
}

// GET SINGLE POST
export async function getPost(req, res) {
  try {
    const post = await Post.findById(req.params.id)
      .populate("user", "username avatar verified");

    if (!post) return res.status(404).json({ message: "Post not found" });

    res.json(formatPost(post, req.user._id));
  } catch (e) {
    res.status(500).json({ message: "Get post failed" });
  }
}

// DELETE POST
export async function deletePost(req, res) {
  try {
    const post = await Post.findOneAndDelete({ _id: req.params.id, user: req.user._id });
    if (!post) return res.status(404).json({ message: "Post not found" });

    await User.findByIdAndUpdate(req.user._id, { $inc: { postsCount: -1 } });
    await Comment.deleteMany({ post: req.params.id });

    res.json({ deleted: true });
  } catch (e) {
    res.status(500).json({ message: "Delete post failed" });
  }
}

// TOGGLE LIKE
export async function toggleLike(req, res) {
  try {
    const post = await Post.findById(req.params.id);
    if (!post) return res.status(404).json({ message: "Post not found" });

    const liked = post.likes.some(id => id.toString() === req.user._id.toString());

    const updated = await Post.findByIdAndUpdate(
      req.params.id,
      liked
        ? { $pull: { likes: req.user._id } }
        : { $addToSet: { likes: req.user._id } },
      { new: true }
    );

    res.json({
      liked: !liked,
      likesCount: updated.likes.length,
    });
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Toggle like failed" });
  }
}

// TOGGLE SAVE
export async function toggleSave(req, res) {
  try {
    const post = await Post.findById(req.params.id);
    if (!post) return res.status(404).json({ message: "Post not found" });

    const saved = post.saves?.some(id => id.toString() === req.user._id.toString());

    await Post.findByIdAndUpdate(
      req.params.id,
      saved
        ? { $pull: { saves: req.user._id } }
        : { $addToSet: { saves: req.user._id } }
    );

    res.json({ saved: !saved });
  } catch (e) {
    res.status(500).json({ message: "Toggle save failed" });
  }
      }
