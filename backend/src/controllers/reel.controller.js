import { Reel } from "../models/reel.model.js";

export async function getReels(req, res) {
  const reels = await Reel.find()
    .populate("user", "username avatar verified")
    .sort({ createdAt: -1 });

  res.json(reels);
}

export async function addView(req, res) {
  await Reel.findByIdAndUpdate(
    req.params.id,
    { $addToSet: { views: req.user._id } }
  );
  res.json({ viewed: true });
}

export async function toggleLike(req, res) {
  const reel = await Reel.findById(req.params.id);
  const liked = reel.likes.includes(req.user._id);

  await Reel.findByIdAndUpdate(
    req.params.id,
    liked
      ? { $pull: { likes: req.user._id } }
      : { $addToSet: { likes: req.user._id } }
  );

  res.json({ liked: !liked });
}

export async function toggleSave(req, res) {
  const reel = await Reel.findById(req.params.id);
  const saved = reel.saves.includes(req.user._id);

  await Reel.findByIdAndUpdate(
    req.params.id,
    saved
      ? { $pull: { saves: req.user._id } }
      : { $addToSet: { saves: req.user._id } }
  );

  res.json({ saved: !saved });
}
