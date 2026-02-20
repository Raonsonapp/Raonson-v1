import { Story } from "../models/story.model.js";

export async function getStories(req, res) {
  try {
    const stories = await Story.find({
      expiresAt: { $gte: new Date() },
    })
      .populate("user", "username avatar verified")
      .sort({ createdAt: -1 });

    res.json(stories);
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Get stories failed" });
  }
}

export async function createStory(req, res) {
  try {
    const { mediaUrl, mediaType } = req.body;
    if (!mediaUrl || !mediaType) {
      return res.status(400).json({ message: "mediaUrl and mediaType required" });
    }

    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24h

    const story = await Story.create({
      user: req.user._id,
      mediaUrl,
      mediaType,
      expiresAt,
    });

    res.status(201).json(story);
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Create story failed" });
  }
}

export async function viewStory(req, res) {
  try {
    await Story.findByIdAndUpdate(
      req.params.id,
      { $addToSet: { views: req.user._id } }
    );
    res.json({ viewed: true });
  } catch (e) {
    res.status(500).json({ message: "View story failed" });
  }
}

export async function likeStory(req, res) {
  try {
    const story = await Story.findById(req.params.id);
    if (!story) return res.status(404).json({ message: "Story not found" });

    const liked = story.likes.includes(req.user._id);
    await Story.findByIdAndUpdate(
      req.params.id,
      liked
        ? { $pull: { likes: req.user._id } }
        : { $addToSet: { likes: req.user._id } }
    );

    res.json({ liked: !liked });
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Like story failed" });
  }
}

export async function deleteStory(req, res) {
  try {
    const story = await Story.findOneAndDelete({ _id: req.params.id, user: req.user._id });
    if (!story) return res.status(404).json({ message: "Story not found" });
    res.json({ deleted: true });
  } catch (e) {
    res.status(500).json({ message: "Delete story failed" });
  }
}
