import Comment from "../models/comment.model.js";

// ADD COMMENT
export const addComment = async (req, res) => {
  const { postId } = req.params;
  const { text } = req.body;

  if (!text) {
    return res.status(400).json({ error: "Text required" });
  }

  const comment = await Comment.create({
    userId: req.user.id,
    postId,
    text,
  });

  res.json(comment);
};

// GET COMMENTS FOR POST
export const getComments = async (req, res) => {
  const { postId } = req.params;

  const comments = await Comment.find({ postId })
    .sort({ createdAt: -1 })
    .limit(50);

  res.json(comments);
};
