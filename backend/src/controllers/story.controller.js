import { stories } from "../data/stories.store.js";

const DAY = 24 * 60 * 60 * 1000;

// GET STORIES
export const getStories = (req, res) => {
  const now = Date.now();

  const active = stories.filter(
    s => now - new Date(s.createdAt).getTime() < DAY
  );

  const grouped = {};
  for (const s of active) {
    if (!grouped[s.user]) grouped[s.user] = [];
    grouped[s.user].push(s);
  }

  res.json(grouped);
};

// CREATE STORY (WITH FILE)
export const createStory = (req, res) => {
  const { user, mediaType } = req.body;
  if (!req.file) {
    return res.status(400).json({ error: "File missing" });
  }

  const mediaUrl = `${req.protocol}://${req.get("host")}/uploads/stories/${req.file.filename}`;

  const story = {
    id: Date.now().toString(),
    user,
    mediaUrl,
    mediaType,
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
  if (!story) return res.status(404).json({ error: "Not found" });

  if (!story.views.includes(user)) {
    story.views.push(user);
  }

  res.json({ views: story.views.length });
};
