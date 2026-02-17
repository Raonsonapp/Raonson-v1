import { Reel } from "../models/reel.model.js";

export async function getReels() {
  return Reel.find()
    .populate("user", "username avatar verified")
    .sort({ createdAt: -1 })
    .limit(50);
}

export async function addReelView(reelId, userId) {
  await Reel.findByIdAndUpdate(reelId, {
    $addToSet: { views: userId },
  });
}

export async function toggleReelLike(reelId, userId) {
  const reel = await Reel.findById(reelId);
  if (!reel) return null;

  const liked = reel.likes.includes(userId);

  await Reel.findByIdAndUpdate(
    reelId,
    liked
      ? { $pull: { likes: userId } }
      : { $addToSet: { likes: userId } }
  );

  return { liked: !liked };
}
