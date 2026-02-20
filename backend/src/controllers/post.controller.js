import { Post } from "../models/post.model.js";
import { User } from "../models/user.model.js";
import { Comment } from "../models/comment.model.js";

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

    res.status(201).json(post);
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Create post failed" });
  }
}

// GET FEED (with pagination)
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

    res.json({ posts, page, limit });
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

    res.json(post);
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
    console.error(e);
    res.status(500).json({ message: "Delete post failed" });
  }
}

// TOGGLE LIKE
export async function toggleLike(req, res) {
  try {
    const post = await Post.findById(req.params.id);
    if (!post) return res.status(404).json({ message: "Post not found" });

    const liked = post.likes.includes(req.user._id);

    await Post.findByIdAndUpdate(
      req.params.id,
      liked ? { $pull: { likes: req.user._id } } : { $addToSet: { likes: req.user._id } }
    );

    res.json({ liked: !liked });
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

    const saved = post.saves.includes(req.user._id);

    await Post.findByIdAndUpdate(
      req.params.id,
      saved ? { $pull: { saves: req.user._id } } : { $addToSet: { saves: req.user._id } }
    );

    res.json({ saved: !saved });
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Toggle save failed" });
  }
}
