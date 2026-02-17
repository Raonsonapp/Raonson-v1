import { User } from "../models/user.model.js";

export async function toggleFollow(req, res) {
  const target = await User.findById(req.params.userId);
  const me = await User.findById(req.user._id);

  const isFollowing = me.following.includes(target._id);

  if (isFollowing) {
    me.following.pull(target._id);
    target.followers.pull(me._id);
  } else {
    if (target.isPrivate) {
      target.followRequests.addToSet(me._id);
      await target.save();
      return res.json({ requested: true });
    }
    me.following.addToSet(target._id);
    target.followers.addToSet(me._id);
  }

  await me.save();
  await target.save();

  res.json({ following: !isFollowing });
}
