import { comments } from "../data/comments.store.js";
import { v4 as uuid } from "uuid";

export const getComments = (req, res) => {
  const { reelId } = req.params;
  const list = comments.filter(c => c.reelId === reelId);
  res.json(list);
};

export const addComment = (req, res) => {
  const { reelId } = req.params;
  const { text } = req.body;

  if (!text) {
    return res.status(400).json({ error: "Text required" });
  }

  const comment = {
    id: uuid(),
    reelId,
    user: "guest",
    text,
    createdAt: new Date(),
  };

  comments.unshift(comment);
  res.json(comment);
};
