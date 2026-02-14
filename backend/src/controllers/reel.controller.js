import { reels } from "../data/reels.store.js";

// GET FEED
export const getReels = (req, res) => {
  res.json(reels);
};

// ADD VIEW
export const addView = (req, res) => {
  const reel = reels.find(r => r.id === req.params.id);
  if (!reel) return res.status(404).json({ error: "Reel not found" });

  reel.views += 1;
  res.json({ views: reel.views });
};

// TOGGLE LIKE
export const toggleLike = (req, res) => {
  const reel = reels.find(r => r.id === req.params.id);
  if (!reel) return res.status(404).json({ error: "Reel not found" });

  reel.likes += 1; // MVP: ҳар tap = +1
  res.json({ likes: reel.likes });
};
