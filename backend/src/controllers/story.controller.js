import { Story } from "../models/story.model.js";

export async function getStories(req, res) {
  const stories = await Story.find({
    createdAt: { $gte: new Date(Date.now() - 24 * 60 * 60 * 1000) },
  }).populate("user", "username avatar verified");

  res.json(stories);
}

export async function createStory(req, res) {
  const { mediaUrl, mediaType } = req.body;

  const story = await Story.create({
    user: req.user._id,
    mediaUrl,
    mediaType,
  });

  res.json(story);
}

export async function viewStory(req, res) {
  await Story.findByIdAndUpdate(
    req.params.id,
    { $addToSet: { views: req.user._id } }
  );

  res.json({ viewed: true });
}

export async function likeStory(req, res) {
  const story = await Story.findById(req.params.id);
  const liked = story.likes.includes(req.user._id);

  await Story.findByIdAndUpdate(
    req.params.id,
    liked
      ? { $pull: { likes: req.user._id } }
      : { $addToSet: { likes: req.user._id } }
  );

  res.json({ liked: !liked });
}
