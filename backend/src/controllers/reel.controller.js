import { Reel } from "../models/reel.model.js";

// CREATE REEL
export async function createReel(req, res) {
  try {
    const { caption, videoUrl } = req.body;
    if (!videoUrl) return res.status(400).json({ message: "videoUrl is required" });

    const reel = await Reel.create({ user: req.user._id, caption, videoUrl });
    res.status(201).json(reel);
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Create reel failed" });
  }
}

// GET REELS FEED
export async function getReels(req, res) {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const skip = (page - 1) * limit;

    const reels = await Reel.find()
      .populate("user", "username avatar verified")
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit);

    res.json({ reels, page, limit });
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Get reels failed" });
  }
}

// ADD VIEW
export async function addView(req, res) {
  try {
    await Reel.findByIdAndUpdate(req.params.id, { $inc: { views: 1 } });
    res.json({ viewed: true });
  } catch (e) {
    res.status(500).json({ message: "View failed" });
  }
}

// LIKE / UNLIKE
export async function toggleLike(req, res) {
  try {
    const reel = await Reel.findById(req.params.id);
    if (!reel) return res.status(404).json({ message: "Reel not found" });

    const userId = req.user._id;
    const liked = reel.likes.includes(userId);

    await Reel.findByIdAndUpdate(
      req.params.id,
      liked ? { $pull: { likes: userId } } : { $addToSet: { likes: userId } }
    );

    res.json({ liked: !liked });
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Toggle like failed" });
  }
}

// SAVE / UNSAVE
export async function toggleSave(req, res) {
  try {
    const reel = await Reel.findById(req.params.id);
    if (!reel) return res.status(404).json({ message: "Reel not found" });

    const userId = req.user._id;
    const saved = reel.saves.includes(userId);

    await Reel.findByIdAndUpdate(
      req.params.id,
      saved ? { $pull: { saves: userId } } : { $addToSet: { saves: userId } }
    );

    res.json({ saved: !saved });
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Toggle save failed" });
  }
}

// DELETE REEL
export async function deleteReel(req, res) {
  try {
    const reel = await Reel.findOneAndDelete({ _id: req.params.id, user: req.user._id });
    if (!reel) return res.status(404).json({ message: "Reel not found" });
    res.json({ deleted: true });
  } catch (e) {
    res.status(500).json({ message: "Delete failed" });
  }
}
