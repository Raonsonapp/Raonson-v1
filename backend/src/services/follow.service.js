import { Follow } from "../models/follow.model.js";
import { User } from "../models/user.model.js";
import { addNotification } from "./notification.service.js";

export async function followUser({ from, to }) {
  if (from.equals(to)) throw new Error("Cannot follow yourself");

  const target = await User.findById(to);
  if (!target) throw new Error("User not found");

  const exists = await Follow.findOne({ from, to });
  if (exists) return exists;

  // PRIVATE → REQUEST
  if (target.isPrivate) {
    const req = await Follow.create({
      from,
      to,
      status: "pending",
    });

    await addNotification({
      to,
      from,
      type: "follow_request",
    });

    return req;
  }

  // PUBLIC → AUTO FOLLOW
  const follow = await Follow.create({
    from,
    to,
    status: "accepted",
  });

  await User.findByIdAndUpdate(from, {
    $inc: { followingCount: 1 },
  });

  await User.findByIdAndUpdate(to, {
    $inc: { followersCount: 1 },
  });

  await addNotification({
    to,
    from,
    type: "follow",
  });

  return follow;
}

export async function unfollowUser({ from, to }) {
  const follow = await Follow.findOneAndDelete({
    from,
    to,
    status: "accepted",
  });

  if (!follow) return;

  await User.findByIdAndUpdate(from, {
    $inc: { followingCount: -1 },
  });

  await User.findByIdAndUpdate(to, {
    $inc: { followersCount: -1 },
  });
}

export async function acceptRequest({ owner, from }) {
  const req = await Follow.findOne({
    from,
    to: owner,
    status: "pending",
  });

  if (!req) throw new Error("Request not found");

  req.status = "accepted";
  await req.save();

  await User.findByIdAndUpdate(owner, {
    $inc: { followersCount: 1 },
  });

  await User.findByIdAndUpdate(from, {
    $inc: { followingCount: 1 },
  });

  await addNotification({
    to: from,
    from: owner,
    type: "follow_accept",
  });

  return req;
}

export async function rejectRequest({ owner, from }) {
  await Follow.findOneAndDelete({
    from,
    to: owner,
    status: "pending",
  });
}
