import { Comment } from "../models/comment.model.js";
import { Post } from "../models/post.model.js";

export async function addComment(req, res) {
  try {
    const { text } = req.body;
    const postId = req.params.postId;

    if (!text?.trim()) return res.status(400).json({ message: "Comment text required" });

    const post = await Post.findById(postId);
    if (!post) return res.status(404).json({ message: "Post not found" });

    const comment = await Comment.create({
      user: req.user._id,
      post: postId,
      text: text.trim(),
    });

    await Post.findByIdAndUpdate(postId, { $inc: { commentsCount: 1 } });
    const populated = await comment.populate("user", "username avatar verified");

    const obj = populated.toObject();
    obj.liked = false;
    res.status(201).json(obj);
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
    const userId = req.user._id;

    const comments = await Comment.find({ post: req.params.postId })
      .populate("user", "username avatar verified")
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit);

    // Add liked per user
    const formatted = comments.map(c => {
      const obj = c.toObject();
      obj.liked = obj.likes?.some(id => id.toString() === userId.toString()) ?? false;
      return obj;
    });

    res.json({ comments: formatted, page, limit });
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
    res.status(500).json({ message: "Delete comment failed" });
  }
}

export async function toggleCommentLike(req, res) {
  try {
    const comment = await Comment.findById(req.params.id);
    if (!comment) return res.status(404).json({ message: "Comment not found" });

    const liked = comment.likes.some(id => id.toString() === req.user._id.toString());

    await Comment.findByIdAndUpdate(
      req.params.id,
      liked ? { $pull: { likes: req.user._id } } : { $addToSet: { likes: req.user._id } }
    );

    res.json({ liked: !liked });
  } catch (e) {
    res.status(500).json({ message: "Toggle like failed" });
  }
}
