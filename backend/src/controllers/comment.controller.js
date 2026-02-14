import { comments } from "../data/comments.store.js";
import { v4 as uuid } from "uuid";

// GET COMMENTS FOR REEL
export const getComments = (req, res) => {
  const { reelId } = req.params;
  const reelComments = comments.filter(c => c.reelId === reelId);
  res.json(reelComments);
};

// ADD COMMENT
export const addComment = (req, res) => {
  const { reelId } = req.params;
  const { text, user } = req.body;

  if (!text) {
    return res.status(400).json({ error: "Text required" });
  }

  const comment = {
    id: uuid(),
    reelId,
    user: user || "guest_user",
    text,
    createdAt: new Date()
  };

  comments.unshift(comment);
  res.json(comment);
};
