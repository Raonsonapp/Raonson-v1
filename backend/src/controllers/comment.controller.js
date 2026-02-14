import Comment from "../models/comment.model.js";

// ADD COMMENT (POST ё REEL)
export const addComment = async (req, res) => {
  const { targetId, targetType } = req.params;
  const { text } = req.body;

  if (!text) {
    return res.status(400).json({ error: "Text required" });
  }

  const comment = await Comment.create({
    userId: req.user.id,
    targetId,
    targetType,
    text,
  });

  res.json(comment);
};

// GET COMMENTS
export const getComments = async (req, res) => {
  const { targetId, targetType } = req.params;

  const comments = await Comment.find({
    targetId,
    targetType,
  })
    .sort({ createdAt: -1 })
    .limit(50);

  res.json(comments);
};
