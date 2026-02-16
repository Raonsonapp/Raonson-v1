import { Comment } from "../models/comment.model.js";
import { Post } from "../models/post.model.js";
import { addNotification } from "./notification.controller.js";

// ================= GET COMMENTS =================
export async function getComments(req, res) {
  const { postId } = req.params;

  const comments = await Comment.find({ post: postId, parent: null })
    .populate("user", "username avatar verified")
    .sort({ createdAt: -1 });

  const withReplies = await Promise.all(
    comments.map(async c => {
      const replies = await Comment.find({ parent: c._id })
        .populate("user", "username avatar verified")
        .sort({ createdAt: 1 });

      return {
        ...c.toObject(),
        replies,
        likesCount: c.likes.length,
      };
    })
  );

  res.json(withReplies);
}

// ================= ADD COMMENT =================
export async function addComment(req, res) {
  const { postId } = req.params;
  const { text, parentId } = req.body;

  const comment = await Comment.create({
    post: postId,
    user: req.user._id,
    text,
    parent: parentId || null,
  });

  await Post.findByIdAndUpdate(postId, {
    $inc: { commentsCount: 1 },
  });

  const post = await Post.findById(postId);

  if (String(post.user) !== String(req.user._id)) {
    addNotification({
      to: post.user,
      from: req.user._id,
      type: "comment",
      postId,
    });
  }

  res.json(comment);
}

// ================= LIKE COMMENT =================
export async function toggleLikeComment(req, res) {
  const { id } = req.params;
  const userId = req.user._id;

  const comment = await Comment.findById(id);
  const liked = comment.likes.includes(userId);

  await Comment.findByIdAndUpdate(
    id,
    liked
      ? { $pull: { likes: userId } }
      : { $addToSet: { likes: userId } }
  );

  res.json({ liked: !liked });
}
