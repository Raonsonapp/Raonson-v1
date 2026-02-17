import { Story } from "../models/story.model.js";

const DAY = 24 * 60 * 60 * 1000;

export async function getActiveStories() {
  const since = new Date(Date.now() - DAY);

  return Story.find({ createdAt: { $gte: since } })
    .populate("user", "username avatar verified")
    .sort({ createdAt: -1 });
}

export async function createStory(userId, mediaUrl, mediaType) {
  return Story.create({
    user: userId,
    mediaUrl,
    mediaType,
  });
}

export async function viewStory(storyId, userId) {
  await Story.findByIdAndUpdate(storyId, {
    $addToSet: { views: userId },
  });
}
