import { Reel } from "../models/reel.model.js";

// CREATE REEL
export async function createReel(req, res) {
  const { caption, mediaUrl } = req.body;

  const reel = await Reel.create({
    user: req.user.id,
    caption,
    mediaUrl,
  });

  res.json(reel);
}

// GET REELS FEED
export async function getReels(req, res) {
  const reels = await Reel.find()
    .populate("user", "username avatar verified")
    .sort({ createdAt: -1 })
    .limit(50);

  res.json(reels);
}

// ADD VIEW
export async function addView(req, res) {
  await Reel.findByIdAndUpdate(req.params.id, {
    $inc: { views: 1 },
  });

  res.json({ viewed: true });
}

// LIKE / UNLIKE
export async function toggleLike(req, res) {
  const reel = await Reel.findById(req.params.id);
  const userId = req.user.id;

  const liked = reel.likes.includes(userId);

  await Reel.findByIdAndUpdate(req.params.id, liked
    ? { $pull: { likes: userId } }
    : { $addToSet: { likes: userId } }
  );

  res.json({ liked: !liked });
}

// SAVE / UNSAVE
export async function toggleSave(req, res) {
  const reel = await Reel.findById(req.params.id);
  const userId = req.user.id;

  const saved = reel.saves.includes(userId);

  await Reel.findByIdAndUpdate(req.params.id, saved
    ? { $pull: { saves: userId } }
    : { $addToSet: { saves: userId } }
  );

  res.json({ saved: !saved });
}
