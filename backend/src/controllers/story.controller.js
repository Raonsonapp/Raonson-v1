import { Story } from "../models/story.model.js";
import { canViewStories, getVisibleStories } from "../services/story.service.js";

// GET STORIES (HOME BAR)
export async function getStories(req, res) {
  const stories = await getVisibleStories(req.user._id);

  // group by user (Instagram-style)
  const grouped = {};
  stories.forEach((s) => {
    const uid = s.user._id.toString();
    if (!grouped[uid]) grouped[uid] = [];
    grouped[uid].push(s);
  });

  res.json(grouped);
}

// CREATE STORY
export async function createStory(req, res) {
  const { mediaUrl, mediaType } = req.body;

  const story = await Story.create({
    user: req.user._id,
    mediaUrl,
    mediaType,
    expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
  });

  res.json(story);
}

// VIEW STORY
export async function viewStory(req, res) {
  const story = await Story.findById(req.params.id);
  if (!story) return res.sendStatus(404);

  const allowed = await canViewStories({
    viewer: req.user._id,
    owner: story.user,
  });
  if (!allowed) return res.sendStatus(403);

  if (!story.views.includes(req.user._id)) {
    story.views.push(req.user._id);
    await story.save();
  }

  res.sendStatus(200);
}

// LIKE STORY
export async function likeStory(req, res) {
  const story = await Story.findById(req.params.id);
  if (!story) return res.sendStatus(404);

  const liked = story.likes.includes(req.user._id);

  await Story.findByIdAndUpdate(req.params.id, liked
    ? { $pull: { likes: req.user._id } }
    : { $addToSet: { likes: req.user._id } }
  );

  res.json({ liked: !liked });
     }
