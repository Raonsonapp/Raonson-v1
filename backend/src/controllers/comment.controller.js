import { Comment } from "../models/comment.model.js";
import { Post } from "../models/post.model.js";

// ADD COMMENT
export async function addComment(req, res) {
  const { postId, text, parentId } = req.body;

  const comment = await Comment.create({
    post: postId,
    user: req.user._id,
    text,
    parent: parentId || null,
  });

  // sync counter
  await Post.findByIdAndUpdate(postId, {
    $inc: { commentsCount: 1 },
  });

  res.json(comment);
}

// GET COMMENTS FOR POST
export async function getComments(req, res) {
  const comments = await Comment.find({
    post: req.params.postId,
  })
    .populate("user", "username avatar verified")
    .sort({ createdAt: 1 });

  res.json(comments);
}

// DELETE COMMENT
export async function deleteComment(req, res) {
  const comment = await Comment.findById(req.params.id);
  if (!comment) return res.sendStatus(404);

  // only owner can delete
  if (comment.user.toString() !== req.user._id.toString()) {
    return res.sendStatus(403);
  }

  await Comment.deleteMany({
    $or: [{ _id: comment._id }, { parent: comment._id }],
  });

  await Post.findByIdAndUpdate(comment.post, {
    $inc: { commentsCount: -1 },
  });

  res.json({ success: true });
    }
