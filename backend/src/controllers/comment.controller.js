import { Comment } from "../models/comment.model.js";
import { Post } from "../models/post.model.js";

export async function addComment(req, res) {
  try {
    const { text } = req.body;
    const postId = req.params.postId;

    if (!text?.trim()) {
      return res.status(400).json({ message: "Comment text required" });
    }

    const post = await Post.findById(postId);
    if (!post) return res.status(404).json({ message: "Post not found" });

    const comment = await Comment.create({
      user: req.user._id,
      post: postId,
      text: text.trim(),
    });

    await Post.findByIdAndUpdate(postId, { $inc: { commentsCount: 1 } });

    const populated = await comment.populate("user", "username avatar verified");

    res.status(201).json(populated);
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Add comment failed" });
  }
}

export async function getComments(req, res) {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const skip = (page - 1) * limit;

    const comments = await Comment.find({ post: req.params.postId })
      .populate("user", "username avatar verified")
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit);

    res.json({ comments, page, limit });
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Get comments failed" });
  }
}

export async function deleteComment(req, res) {
  try {
    const comment = await Comment.findOneAndDelete({
      _id: req.params.id,
      user: req.user._id,
    });

    if (!comment) return res.status(404).json({ message: "Comment not found" });

    await Post.findByIdAndUpdate(comment.post, { $inc: { commentsCount: -1 } });

    res.json({ success: true });
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Delete comment failed" });
  }
}

export async function toggleCommentLike(req, res) {
  try {
    const comment = await Comment.findById(req.params.id);
    if (!comment) return res.status(404).json({ message: "Comment not found" });

    const liked = comment.likes.includes(req.user._id);

    await Comment.findByIdAndUpdate(
      req.params.id,
      liked ? { $pull: { likes: req.user._id } } : { $addToSet: { likes: req.user._id } }
    );

    res.json({ liked: !liked });
  } catch (e) {
    res.status(500).json({ message: "Toggle like failed" });
  }
}
