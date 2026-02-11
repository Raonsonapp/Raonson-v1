import Reel from "../models/reel.model.js";

// CREATE REEL
export const createReel = async (req, res) => {
  const { videoUrl, caption } = req.body;

  if (!videoUrl) {
    return res.status(400).json({ error: "videoUrl required" });
  }

  const reel = await Reel.create({
    userId: req.user.id,
    videoUrl,
    caption,
  });

  res.json(reel);
};

// GET REELS FEED
export const getReels = async (req, res) => {
  const reels = await Reel.find()
    .sort({ createdAt: -1 })
    .limit(20);

  res.json(reels);
};

// ADD VIEW
export const addView = async (req, res) => {
  const { reelId } = req.params;

  await Reel.findByIdAndUpdate(reelId, {
    $inc: { viewsCount: 1 },
  });

  res.json({ viewed: true });
};
