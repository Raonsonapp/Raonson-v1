import { Follow } from "../models/follow.model.js";
import { User } from "../models/user.model.js";
import { addNotification } from "./notification.controller.js";

// FOLLOW / UNFOLLOW
export async function toggleFollow(req, res) {
  const targetUserId = req.params.userId;
  const myId = req.user._id;

  if (targetUserId === myId.toString()) {
    return res.status(400).json({ error: "Cannot follow yourself" });
  }

  const existing = await Follow.findOne({
    from: myId,
    to: targetUserId,
  });

  if (existing) {
    // UNFOLLOW
    await existing.deleteOne();

    await User.findByIdAndUpdate(myId, {
      $inc: { followingCount: -1 },
    });
    await User.findByIdAndUpdate(targetUserId, {
      $inc: { followersCount: -1 },
    });

    return res.json({ following: false });
  }

  // FOLLOW
  await Follow.create({
    from: myId,
    to: targetUserId,
  });

  await User.findByIdAndUpdate(myId, {
    $inc: { followingCount: 1 },
  });
  await User.findByIdAndUpdate(targetUserId, {
    $inc: { followersCount: 1 },
  });

  // notification
  addNotification({
    to: targetUserId,
    from: myId,
    type: "follow",
  });

  res.json({ following: true });
}

// GET FOLLOWERS
export async function getFollowers(req, res) {
  const list = await Follow.find({ to: req.params.userId })
    .populate("from", "username avatar verified")
    .limit(100);

  res.json(list);
}

// GET FOLLOWING
export async function getFollowing(req, res) {
  const list = await Follow.find({ from: req.params.userId })
    .populate("to", "username avatar verified")
    .limit(100);

  res.json(list);
}
