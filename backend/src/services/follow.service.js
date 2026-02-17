import { User } from "../models/user.model.js";

export async function followUser(requesterId, targetId) {
  const target = await User.findById(targetId);

  if (!target) return null;

  if (target.isPrivate) {
    await User.findByIdAndUpdate(targetId, {
      $addToSet: { followRequests: requesterId },
    });
    return { requested: true };
  }

  await User.findByIdAndUpdate(targetId, {
    $addToSet: { followers: requesterId },
    $inc: { followersCount: 1 },
  });

  await User.findByIdAndUpdate(requesterId, {
    $addToSet: { following: targetId },
    $inc: { followingCount: 1 },
  });

  return { following: true };
}

export async function unfollowUser(requesterId, targetId) {
  await User.findByIdAndUpdate(targetId, {
    $pull: { followers: requesterId },
    $inc: { followersCount: -1 },
  });

  await User.findByIdAndUpdate(requesterId, {
    $pull: { following: targetId },
    $inc: { followingCount: -1 },
  });

  return { following: false };
}
