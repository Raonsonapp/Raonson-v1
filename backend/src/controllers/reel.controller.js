import { reels } from "../data/reels.store.js";

export const getReels = (req, res) => {
  res.json(reels);
};

export const addView = (req, res) => {
  const reel = reels.find(r => r.id === req.params.id);
  if (!reel) return res.status(404).json({ error: "Reel not found" });

  reel.views++;
  res.json({ views: reel.views });
};

export const toggleLike = (req, res) => {
  const reel = reels.find(r => r.id === req.params.id);
  if (!reel) return res.status(404).json({ error: "Reel not found" });

  reel.likes++;
  res.json({ likes: reel.likes });
};
