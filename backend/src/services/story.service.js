import { Story } from "../models/story.model.js";
import { Follow } from "../models/follow.model.js";
import { User } from "../models/user.model.js";

export async function canViewStories({ viewer, owner }) {
  if (viewer.equals(owner)) return true;

  const user = await User.findById(owner);
  if (!user.isPrivate) return true;

  const follow = await Follow.findOne({
    from: viewer,
    to: owner,
    status: "accepted",
  });

  return !!follow;
}

export async function getVisibleStories(userId) {
  // find people I can see
  const following = await Follow.find({
    from: userId,
    status: "accepted",
  }).select("to");

  const ids = following.map((f) => f.to);
  ids.push(userId);

  return Story.find({
    user: { $in: ids },
    expiresAt: { $gt: new Date() },
  })
    .populate("user", "username avatar verified")
    .sort({ createdAt: 1 });
}
