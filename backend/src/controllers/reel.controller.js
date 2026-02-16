import { Reel } from "../models/reel.model.js";
import { addNotification } from "./notification.controller.js";

/* ======================================================
   CREATE REEL
====================================================== */
export async function createReel(req, res) {
  try {
    const { videoUrl, caption } = req.body;

    if (!videoUrl) {
      return res.status(400).json({ error: "Video required" });
    }

    const reel = await Reel.create({
      user: req.user._id,
      videoUrl,
      caption,
    });

    const populated = await reel.populate(
      "user",
      "username avatar verified"
    );

    res.json(populated);
  } catch (e) {
    res.status(500).json({ error: "Failed to create reel" });
  }
}

/* ======================================================
   FOR YOU FEED (ALGORITHM)
====================================================== */
export async function getReels(req, res) {
  try {
    const reels = await Reel.find()
      .populate("user", "username avatar verified")
      .sort({ score: -1, createdAt: -1 })
      .limit(50);

    res.json(reels);
  } catch (e) {
    res.status(500).json({ error: "Failed to load reels" });
  }
}

/* ======================================================
   VIEW REEL
====================================================== */
export async function addView(req, res) {
  try {
    await Reel.findByIdAndUpdate(req.params.id, {
      $inc: { views: 1, score: 1 },
    });

    res.json({ viewed: true });
  } catch (e) {
    res.status(500).json({ error: "View failed" });
  }
}

/* ======================================================
   LIKE / UNLIKE
====================================================== */
export async function toggleLike(req, res) {
  try {
    const reel = await Reel.findById(req.params.id);
    if (!reel) return res.sendStatus(404);

    const liked = reel.likedBy.includes(req.user._id);

    await Reel.findByIdAndUpdate(
      reel._id,
      liked
        ? {
            $pull: { likedBy: req.user._id },
            $inc: { score: -2 },
          }
        : {
            $addToSet: { likedBy: req.user._id },
            $inc: { score: 3 },
          }
    );

    if (!liked && reel.user.toString() !== req.user._id.toString()) {
      addNotification({
        to: reel.user,
        from: req.user._id,
        type: "reel_like",
        reelId: reel._id,
      });
    }

    res.json({ liked: !liked });
  } catch (e) {
    res.status(500).json({ error: "Like failed" });
  }
}

/* ======================================================
   SAVE / UNSAVE
====================================================== */
export async function toggleSave(req, res) {
  try {
    const reel = await Reel.findById(req.params.id);
    if (!reel) return res.sendStatus(404);

    const saved = reel.savedBy.includes(req.user._id);

    await Reel.findByIdAndUpdate(
      reel._id,
      saved
        ? {
            $pull: { savedBy: req.user._id },
            $inc: { score: -1 },
          }
        : {
            $addToSet: { savedBy: req.user._id },
            $inc: { score: 2 },
          }
    );

    res.json({ saved: !saved });
  } catch (e) {
    res.status(500).json({ error: "Save failed" });
  }
       }
