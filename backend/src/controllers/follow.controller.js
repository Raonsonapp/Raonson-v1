import { User } from "../models/user.model.js";
import { createNotification } from "./notification.controller.js";

// ================= FOLLOW =================
export async function followUser(req, res, next) {
  try {
    const targetId = req.params.userId;
    const me = req.user._id;

    if (me.equals(targetId)) {
      return res.status(400).json({ error: "Cannot follow yourself" });
    }

    const target = await User.findById(targetId);
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

        await createNotification({
          to: target._id,
          from: me,
          type: "follow_request",
        });
      }

      return res.json({ status: "requested" });
    }

    // PUBLIC → FOLLOW
    await User.findByIdAndUpdate(me, {
      $addToSet: { following: targetId },
      $inc: { followingCount: 1 },
    });

    await User.findByIdAndUpdate(targetId, {
      $addToSet: { followers: me },
      $inc: { followersCount: 1 },
    });

    await createNotification({
      to: targetId,
      from: me,
      type: "follow",
    });

    res.json({ status: "following" });
  } catch (e) {
    next(e);
  }
}

// ================= UNFOLLOW =================
export async function unfollowUser(req, res, next) {
  try {
    const targetId = req.params.userId;
    const me = req.user._id;

    await User.findByIdAndUpdate(me, {
      $pull: { following: targetId },
      $inc: { followingCount: -1 },
    });

    await User.findByIdAndUpdate(targetId, {
      $pull: { followers: me },
      $inc: { followersCount: -1 },
    });

    res.json({ status: "unfollowed" });
  } catch (e) {
    next(e);
  }
}

// ================= ACCEPT REQUEST =================
export async function acceptRequest(req, res, next) {
  try {
    const requesterId = req.params.userId;
    const me = req.user._id;

    const user = await User.findById(me);
    if (!user.followRequests.includes(requesterId)) {
      return res.status(400).json({ error: "No request" });
    }

    // remove request
    await User.findByIdAndUpdate(me, {
      $pull: { followRequests: requesterId },
      $addToSet: { followers: requesterId },
      $inc: { followersCount: 1 },
    });

    await User.findByIdAndUpdate(requesterId, {
      $addToSet: { following: me },
      $inc: { followingCount: 1 },
    });

    await createNotification({
      to: requesterId,
      from: me,
      type: "follow_accept",
    });

    res.json({ status: "accepted" });
  } catch (e) {
    next(e);
  }
}

// ================= REJECT REQUEST =================
export async function rejectRequest(req, res, next) {
  try {
    const requesterId = req.params.userId;
    const me = req.user._id;

    await User.findByIdAndUpdate(me, {
      $pull: { followRequests: requesterId },
    });

    res.json({ status: "rejected" });
  } catch (e) {
    next(e);
  }
}
