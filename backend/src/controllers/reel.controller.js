import { reels } from "../data/reels.store.js";
import { savedReels } from "../data/saved.store.js";

// GET ALL REELS (FEED)
export const getReels = (req, res) => {
  res.json(reels);
};

// ADD VIEW
export const addView = (req, res) => {
  const { id } = req.params;
  const reel = reels.find(r => r.id === id);

  if (!reel) {
    return res.status(404).json({ error: "Reel not found" });
  }

  reel.views += 1;
  res.json({ views: reel.views });
};

// LIKE REEL (каждый тап = +1)
export const toggleLike = (req, res) => {
  const { id } = req.params;
  const reel = reels.find(r => r.id === id);

  if (!reel) {
    return res.status(404).json({ error: "Reel not found" });
  }

  reel.likes += 1;
  res.json({ likes: reel.likes });
};

// SAVE / UNSAVE REEL
export const toggleSave = (req, res) => {
  const { id } = req.params;
  const user = req.body.user || "guest";

  const index = savedReels.findIndex(
    s => s.reelId === id && s.user === user
  );

  if (index === -1) {
    savedReels.push({
      reelId: id,
      user,
      createdAt: new Date(),
    });
    return res.json({ saved: true });
  } else {
    savedReels.splice(index, 1);
    return res.json({ saved: false });
  }
};
