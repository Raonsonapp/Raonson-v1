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

// LIKE
export const likeReel = (req, res) => {
  const reel = reels.find(r => r.id === req.params.id);
  if (!reel) return res.status(404).json({ error: "Reel not found" });

  reel.likes += 1;
  res.json({ likes: reel.likes });
};

// SHARE
export const shareReel = (req, res) => {
  const reel = reels.find(r => r.id === req.params.id);
  if (!reel) return res.status(404).json({ error: "Reel not found" });

  reel.shares += 1;
  res.json({ shares: reel.shares });
};

// SAVE
export const saveReel = (req, res) => {
  const reel = reels.find(r => r.id === req.params.id);
  if (!reel) return res.status(404).json({ error: "Reel not found" });

  reel.saves += 1;
  res.json({ saves: reel.saves });
};
