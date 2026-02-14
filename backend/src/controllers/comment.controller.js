import { comments } from "../data/comments.store.js";
import { reels } from "../data/reels.store.js";

// ADD COMMENT
export const addComment = (req, res) => {
  const { id } = req.params;
  const { text, user } = req.body;

  if (!text) return res.status(400).json({ error: "Text required" });

  const comment = {
    id: `c${comments.length + 1}`,
    reelId: id,
    user: user || "anonymous",
    text,
    createdAt: new Date(),
  };

  comments.push(comment);

  const reel = reels.find(r => r.id === id);
  if (reel) reel.comments += 1;

  res.json(comment);
};

// GET COMMENTS
export const getComments = (req, res) => {
  const { id } = req.params;
  res.json(comments.filter(c => c.reelId === id));
};
