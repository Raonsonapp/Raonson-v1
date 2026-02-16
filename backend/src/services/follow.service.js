import { User } from "../models/user.model.js";

export async function followUser({ fromUser, toUserId }) {
  if (fromUser._id.equals(toUserId)) {
    throw new Error("Cannot follow yourself");
  }

  const target = await User.findById(toUserId);
  if (!target) throw new Error("User not found");

  // already following
  if (target.followers.includes(fromUser._id)) {
    return { status: "already_following" };
  }

  // PRIVATE ACCOUNT → REQUEST
  if (target.isPrivate) {
    if (!target.followRequests.includes(fromUser._id)) {
      target.followRequests.push(fromUser._id);
      await target.save();
    }
    return { status: "requested" };
  }

  // PUBLIC → FOLLOW
  await User.findByIdAndUpdate(toUserId, {
    $addToSet: { followers: fromUser._id },
    $inc: { followersCount: 1 },
  });

  await User.findByIdAndUpdate(fromUser._id, {
    $addToSet: { following: toUserId },
    $inc: { followingCount: 1 },
  });

  return { status: "following" };
}

export async function unfollowUser({ fromUser, toUserId }) {
  await User.findByIdAndUpdate(toUserId, {
    $pull: { followers: fromUser._id },
    $inc: { followersCount: -1 },
  });

  await User.findByIdAndUpdate(fromUser._id, {
    $pull: { following: toUserId },
    $inc: { followingCount: -1 },
  });

  return { status: "unfollowed" };
}

export async function acceptFollow({ user, fromUserId }) {
  const requester = await User.findById(fromUserId);
  if (!requester) throw new Error("User not found");

  await User.findByIdAndUpdate(user._id, {
    $pull: { followRequests: fromUserId },
    $addToSet: { followers: fromUserId },
    $inc: { followersCount: 1 },
  });

  await User.findByIdAndUpdate(fromUserId, {
    $addToSet: { following: user._id },
    $inc: { followingCount: 1 },
  });

  return { status: "accepted" };
}

export async function rejectFollow({ user, fromUserId }) {
  await User.findByIdAndUpdate(user._id, {
    $pull: { followRequests: fromUserId },
  });

  return { status: "rejected" };
}
