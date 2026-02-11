import Follow from "../models/follow.model.js";

// FOLLOW / UNFOLLOW (toggle)
export const toggleFollow = async (req, res) => {
  const followerId = req.user.id;
  const { userId } = req.params;

  if (followerId === userId) {
    return res.status(400).json({ error: "Cannot follow yourself" });
  }

  const existing = await Follow.findOne({ followerId, followingId: userId });

  if (existing) {
    await existing.deleteOne();
    return res.json({ following: false });
  } else {
    await Follow.create({ followerId, followingId: userId });
    return res.json({ following: true });
  }
};

// GET FOLLOWERS
export const getFollowers = async (req, res) => {
  const { userId } = req.params;
  const followers = await Follow.find({ followingId: userId });
  res.json(followers);
};

// GET FOLLOWING
export const getFollowing = async (req, res) => {
  const { userId } = req.params;
  const following = await Follow.find({ followerId: userId });
  res.json(following);
};
