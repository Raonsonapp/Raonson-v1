import { User } from "../models/user.model.js";
import { addNotification } from "./notification.controller.js";

// FOLLOW / REQUEST
export async function followUser(req, res) {
  const me = req.user._id;
  const { id } = req.params; // target user

  if (me.toString() === id) {
    return res.status(400).json({ error: "Cannot follow yourself" });
  }

  const target = await User.findById(id);
  if (!target) return res.status(404).json({ error: "User not found" });

  // already following
  if (target.followers.includes(me)) {
    return res.json({ status: "already_following" });
  }

  // PRIVATE ACCOUNT → REQUEST
  if (target.isPrivate) {
    if (!target.followRequests.includes(me)) {
      target.followRequests.push(me);
      await target.save();

      await addNotification({
        to: target._id,
        from: me,
        type: "follow_request",
      });
    }

    return res.json({ status: "request_sent" });
  }

  // PUBLIC ACCOUNT → DIRECT FOLLOW
  await User.findByIdAndUpdate(me, {
    $addToSet: { following: target._id },
    $inc: { followingCount: 1 },
  });

  await User.findByIdAndUpdate(target._id, {
    $addToSet: { followers: me },
    $inc: { followersCount: 1 },
  });

  await addNotification({
    to: target._id,
    from: me,
    type: "follow",
  });

  res.json({ status: "followed" });
}

// UNFOLLOW
export async function unfollowUser(req, res) {
  const me = req.user._id;
  const { id } = req.params;

  await User.findByIdAndUpdate(me, {
    $pull: { following: id },
    $inc: { followingCount: -1 },
  });

  await User.findByIdAndUpdate(id, {
    $pull: { followers: me },
    $inc: { followersCount: -1 },
  });

  res.json({ status: "unfollowed" });
}

// ACCEPT FOLLOW REQUEST
export async function acceptRequest(req, res) {
  const me = req.user._id;
  const { id } = req.params; // requester

  const user = await User.findById(me);
  if (!user.followRequests.includes(id)) {
    return res.status(400).json({ error: "No such request" });
  }

  await User.findByIdAndUpdate(me, {
    $pull: { followRequests: id },
    $addToSet: { followers: id },
    $inc: { followersCount: 1 },
  });

  await User.findByIdAndUpdate(id, {
    $addToSet: { following: me },
    $inc: { followingCount: 1 },
  });

  await addNotification({
    to: id,
    from: me,
    type: "follow_accept",
  });

  res.json({ status: "accepted" });
}

// REJECT FOLLOW REQUEST
export async function rejectRequest(req, res) {
  const me = req.user._id;
  const { id } = req.params;

  await User.findByIdAndUpdate(me, {
    $pull: { followRequests: id },
  });

  res.json({ status: "rejected" });
       }
