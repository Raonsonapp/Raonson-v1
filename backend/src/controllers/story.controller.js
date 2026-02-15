import { stories } from "../data/stories.store.js";
import { addNotification } from "./notification.controller.js";

const DAY = 24 * 60 * 60 * 1000;

// GET STORIES (24h)
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
    views: [],
    likes: [],
    replies: [],
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

  if (!story.views.includes(user)) story.views.push(user);
  res.json({ views: story.views.length });
};

// ❤️ LIKE STORY
export const likeStory = (req, res) => {
  const { id } = req.params;
  const { user } = req.body;

  const story = stories.find(s => s.id === id);
  if (!story) return res.status(404).json({ error: "Story not found" });

  if (!story.likes.includes(user)) {
    story.likes.push(user);

    if (story.user !== user) {
      addNotification({
        to: story.user,
        from: user,
        type: "story_like",
        storyId: story.id,
      });
    }
  }

  res.json({ likes: story.likes.length });
};

// 💬 REPLY STORY
export const replyStory = (req, res) => {
  const { id } = req.params;
  const { user, text } = req.body;

  const story = stories.find(s => s.id === id);
  if (!story) return res.status(404).json({ error: "Story not found" });
  if (!text) return res.status(400).json({ error: "Text required" });

  story.replies.push({
    id: Date.now().toString(),
    user,
    text,
    createdAt: new Date(),
  });

  if (story.user !== user) {
    addNotification({
      to: story.user,
      from: user,
      type: "story_reply",
      storyId: story.id,
      text,
    });
  }

  res.json({ ok: true });
};
