import { Comment } from "../models/comment.model.js";

export async function addComment(userId, postId, text) {
  return Comment.create({
    user: userId,
    post: postId,
    text,
  });
}

export async function getPostComments(postId) {
  return Comment.find({ post: postId })
    .populate("user", "username avatar verified")
    .sort({ createdAt: -1 });
}

export async function deleteComment(commentId, userId) {
  return Comment.findOneAndDelete({
    _id: commentId,
    user: userId,
  });
}
