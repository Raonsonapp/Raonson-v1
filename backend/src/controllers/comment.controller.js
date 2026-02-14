import { comments } from "../data/comments.store.js";

// GET COMMENTS
export const getComments = (req, res) => {
  const { targetId } = req.params;
  const list = comments.filter(c => c.targetId === targetId);
  res.json(list);
};

// ADD COMMENT
export const addComment = (req, res) => {
  const { targetId } = req.params;
  const { text } = req.body;

  if (!text) {
    return res.status(400).json({ error: "Text required" });
  }

  const comment = {
    id: Date.now().toString(),
    targetId,
    text,
    createdAt: new Date(),
  };

  comments.push(comment);
  res.json(comment);
};
