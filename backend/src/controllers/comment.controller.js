import { Comment } from "../models/comment.model.js";

export async function addComment(req, res) {
  const { text, post } = req.body;

  const comment = await Comment.create({
    user: req.user._id,
    post,
    text,
  });

  res.json(comment);
}

export async function getComments(req, res) {
  const comments = await Comment.find({ post: req.params.postId })
    .populate("user", "username avatar verified")
    .sort({ createdAt: -1 });

  res.json(comments);
}

export async function deleteComment(req, res) {
  await Comment.findOneAndDelete({
    _id: req.params.id,
    user: req.user._id,
  });

  res.json({ success: true });
}
