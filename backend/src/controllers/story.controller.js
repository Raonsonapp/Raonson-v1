import { stories } from "../data/stories.store.js";

// ⏱ 24 hours in ms
const DAY = 24 * 60 * 60 * 1000;

// GET STORIES (only last 24h, grouped by user)
export const getStories = (req, res) => {
  const now = Date.now();

  const activeStories = stories.filter(
    s => now - new Date(s.createdAt).getTime() < DAY
  );

  // group by user
  const grouped = {};
  for (const s of activeStories) {
    if (!grouped[s.user]) grouped[s.user] = [];
    grouped[s.user].push(s);
  }

  res.json(grouped);
};

// CREATE STORY
export const createStory = (req, res) => {
  const { user, mediaUrl, mediaType } = req.body;

  if (!user || !mediaUrl || !mediaType) {
    return res.status(400).json({ error: "Missing fields" });
  }

  const story = {
    id: Date.now().toString(),
    user,
    mediaUrl,
    mediaType, // image | video
    views: [],
    createdAt: new Date(),
  };

  stories.push(story);
  res.json(story);
};

// VIEW STORY
export const viewStory = (req, res) => {
  const { id } = req.params;
  const { user } = req.body;

  const story = stories.find(s => s.id === id);
  if (!story) return res.status(404).json({ error: "Story not found" });

  if (!story.views.includes(user)) {
    story.views.push(user);
  }

  res.json({ views: story.views.length });
};
