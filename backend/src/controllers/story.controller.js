import { stories } from "../data/stories.store.js";

// ⏱ 24 hours
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
    mediaType,
    likes: [],
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

  if (user && !story.views.includes(user)) {
    story.views.push(user);
  }

  res.json({ views: story.views.length });
};

// ❤️ LIKE STORY  ✅ ИН ҶО МУҲИМ
export const likeStory = (req, res) => {
  const { id } = req.params;
  const { user } = req.body;

  const story = stories.find(s => s.id === id);
  if (!story) return res.status(404).json({ error: "Story not found" });

  if (!story.likes.includes(user)) {
    story.likes.push(user);
  }

  res.json({ likes: story.likes.length });
};
