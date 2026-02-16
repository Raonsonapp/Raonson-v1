import { Follow } from "../models/follow.model.js";
import { User } from "../models/user.model.js";

export async function canViewProfile({ viewer, owner }) {
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
