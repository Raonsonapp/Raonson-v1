import { Story } from "../models/story.model.js";
import { addNotification } from "./notification.controller.js";

/* ======================================================
   CREATE STORY
====================================================== */
export async function createStory(req, res) {
  try {
    const { mediaUrl, mediaType } = req.body;

    if (!mediaUrl || !mediaType) {
      return res.status(400).json({ error: "Missing fields" });
    }

    const story = await Story.create({
      user: req.user._id,
      mediaUrl,
      mediaType,
    });

    const populated = await story.populate(
      "user",
      "username avatar verified"
    );

    res.json(populated);
  } catch (err) {
    console.error("CREATE STORY ERROR:", err);
    res.status(500).json({ error: "Failed to create story" });
  }
}

/* ======================================================
   GET STORIES (grouped by user)
====================================================== */
export async function getStories(req, res) {
  try {
    const stories = await Story.find({
      expiresAt: { $gt: new Date() },
    })
      .populate("user", "username avatar verified")
      .sort({ createdAt: 1 })
      .lean();

    // group by user
    const grouped = {};
    for (const s of stories) {
      const uid = s.user._id.toString();
      if (!grouped[uid]) grouped[uid] = [];
      grouped[uid].push(s);
    }

    res.json(grouped);
  } catch (err) {
    console.error("GET STORIES ERROR:", err);
    res.status(500).json({ error: "Failed to load stories" });
  }
}

/* ======================================================
   VIEW STORY
====================================================== */
export async function viewStory(req, res) {
  try {
    await Story.findByIdAndUpdate(req.params.id, {
      $addToSet: { views: req.user._id },
    });

    res.json({ viewed: true });
  } catch (err) {
    res.status(500).json({ error: "Failed to view story" });
  }
}

/* ======================================================
   LIKE / UNLIKE STORY
====================================================== */
export async function toggleLikeStory(req, res) {
  try {
    const story = await Story.findById(req.params.id);
    if (!story) {
      return res.status(404).json({ error: "Story not found" });
    }

    const liked = story.likes.includes(req.user._id);

    await Story.findByIdAndUpdate(
      story._id,
      liked
        ? { $pull: { likes: req.user._id } }
        : { $addToSet: { likes: req.user._id } }
    );

    if (!liked && story.user.toString() !== req.user._id.toString()) {
      addNotification({
        to: story.user,
        from: req.user._id,
        type: "story_like",
        storyId: story._id,
      });
    }

    res.json({ liked: !liked });
  } catch (err) {
    res.status(500).json({ error: "Failed to like story" });
  }
}
