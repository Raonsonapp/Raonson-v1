import Post from "../models/post.model.js";

// CREATE POST
export const createPost = async (req, res) => {
  const { mediaUrl, mediaType, caption } = req.body;

  if (!mediaUrl || !mediaType) {
    return res.status(400).json({ error: "mediaUrl & mediaType required" });
  }

  const post = await Post.create({
    userId: req.user.id,
    mediaUrl,
    mediaType,
    caption,
  });

  res.json(post);
};

// GET FEED
export const getFeed = async (req, res) => {
  const posts = await Post.find().sort({ createdAt: -1 }).limit(20);
  res.json(posts);
};
