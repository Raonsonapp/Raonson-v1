import { Story } from "../models/story.model.js";

// GET ALL STORIES (for feed - others' stories only, not own)
export async function getStories(req, res) {
  try {
    const stories = await Story.find({
      expiresAt: { $gte: new Date() },
    })
      .populate("user", "username avatar verified")
      .sort({ createdAt: -1 });

    // Add isOwn field
    const userId = req.user._id.toString();
    const formatted = stories.map(s => ({
      ...s.toObject(),
      isOwn: s.user._id.toString() === userId,
    }));

    res.json(formatted);
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Get stories failed" });
  }
}

// GET MY STORIES
export async function getMyStories(req, res) {
  try {
    const stories = await Story.find({
      user: req.user._id,
      expiresAt: { $gte: new Date() },
    })
      .populate("user", "username avatar verified")
      .sort({ createdAt: -1 });

    res.json(stories);
  } catch (e) {
    res.status(500).json({ message: "Get my stories failed" });
  }
}

// CREATE STORY
export async function createStory(req, res) {
  try {
    const { mediaUrl, mediaType } = req.body;
    if (!mediaUrl || !mediaType) {
      return res.status(400).json({ message: "mediaUrl and mediaType required" });
    }

    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000);

    const story = await Story.create({
      user: req.user._id,
      mediaUrl,
      mediaType,
      expiresAt,
    });

    await story.populate("user", "username avatar verified");
    res.status(201).json(story);
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Create story failed" });
  }
}

export async function viewStory(req, res) {
  try {
    await Story.findByIdAndUpdate(req.params.id, { $addToSet: { views: req.user._id } });
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
    await Story.findByIdAndUpdate(req.params.id,
      liked ? { $pull: { likes: req.user._id } } : { $addToSet: { likes: req.user._id } }
    );
    res.json({ liked: !liked });
  } catch (e) {
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
