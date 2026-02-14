import Reel from "../models/reel.model.js";

// ❤️ TOGGLE LIKE
export const toggleLike = async (req, res) => {
  const userId = req.user.id;
  const { reelId } = req.params;

  const reel = await Reel.findById(reelId);
  if (!reel) {
    return res.status(404).json({ error: "Reel not found" });
  }

  const alreadyLiked = reel.likes.includes(userId);

  if (alreadyLiked) {
    reel.likes.pull(userId);
    reel.likesCount -= 1;
  } else {
    reel.likes.push(userId);
    reel.likesCount += 1;
  }

  await reel.save();

  res.json({
    liked: !alreadyLiked,
    likesCount: reel.likesCount,
  });
};
