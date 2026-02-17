import { User } from "../models/user.model.js";

// FOLLOW
export async function followUser(req, res) {
  const targetId = req.params.id;
  const userId = req.user.id;

  const target = await User.findById(targetId);
  if (!target) return res.status(404).json({ message: "User not found" });

  if (target.isPrivate) {
    if (!target.followRequests.includes(userId)) {
      target.followRequests.push(userId);
      await target.save();
    }
    return res.json({ requested: true });
  }

  await User.findByIdAndUpdate(targetId, {
    $addToSet: { followers: userId },
    $inc: { followersCount: 1 },
  });

  await User.findByIdAndUpdate(userId, {
    $addToSet: { following: targetId },
    $inc: { followingCount: 1 },
  });

  res.json({ following: true });
}

// UNFOLLOW
export async function unfollowUser(req, res) {
  const targetId = req.params.id;
  const userId = req.user.id;

  await User.findByIdAndUpdate(targetId, {
    $pull: { followers: userId },
    $inc: { followersCount: -1 },
  });

  await User.findByIdAndUpdate(userId, {
    $pull: { following: targetId },
    $inc: { followingCount: -1 },
  });

  res.json({ following: false });
}

// ACCEPT FOLLOW REQUEST
export async function acceptRequest(req, res) {
  const requesterId = req.params.id;
  const userId = req.user.id;

  await User.findByIdAndUpdate(userId, {
    $pull: { followRequests: requesterId },
    $addToSet: { followers: requesterId },
    $inc: { followersCount: 1 },
  });

  await User.findByIdAndUpdate(requesterId, {
    $addToSet: { following: userId },
    $inc: { followingCount: 1 },
  });

  res.json({ accepted: true });
}

// REJECT FOLLOW REQUEST
export async function rejectRequest(req, res) {
  const requesterId = req.params.id;
  const userId = req.user.id;

  await User.findByIdAndUpdate(userId, {
    $pull: { followRequests: requesterId },
  });

  res.json({ rejected: true });
      }
