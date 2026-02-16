import { Follow } from "../models/follow.model.js";
import { User } from "../models/user.model.js";
import { addNotification } from "./notification.controller.js";

/* ======================================================
   FOLLOW / UNFOLLOW
====================================================== */
export async function toggleFollow(req, res) {
  const targetId = req.params.id;
  const userId = req.user._id;

  if (targetId === String(userId)) {
    return res.status(400).json({ error: "Cannot follow yourself" });
  }

  const exists = await Follow.findOne({
    follower: userId,
    following: targetId,
  });

  if (exists) {
    // UNFOLLOW
    await Follow.deleteOne({ _id: exists._id });

    await User.findByIdAndUpdate(userId, {
      $inc: { followingCount: -1 },
    });
    await User.findByIdAndUpdate(targetId, {
      $inc: { followersCount: -1 },
    });

    return res.json({ following: false });
  }

  // FOLLOW
  await Follow.create({
    follower: userId,
    following: targetId,
  });

  await User.findByIdAndUpdate(userId, {
    $inc: { followingCount: 1 },
  });
  await User.findByIdAndUpdate(targetId, {
    $inc: { followersCount: 1 },
  });

  // 🔔 notification
  await addNotification({
    to: targetId,
    from: userId,
    type: "follow",
  });

  res.json({ following: true });
}

/* ======================================================
   CHECK FOLLOW STATUS
====================================================== */
export async function isFollowing(req, res) {
  const targetId = req.params.id;

  const exists = await Follow.findOne({
    follower: req.user._id,
    following: targetId,
  });

  res.json({ following: !!exists });
}
