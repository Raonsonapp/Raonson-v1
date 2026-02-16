import { User } from "../models/user.model.js";

export async function toggleFollow(req, res, next) {
  try {
    const target = await User.findById(req.params.id);
    const me = req.user;

    if (!target) return res.status(404).json({ error: "User not found" });

    const isFollowing = target.followers.includes(me._id);

    // PRIVATE → REQUEST
    if (target.isPrivate && !isFollowing) {
      if (!target.followRequests.includes(me._id)) {
        target.followRequests.push(me._id);
        await target.save();
      }
      return res.json({ requested: true });
    }

    // FOLLOW / UNFOLLOW
    await User.findByIdAndUpdate(target._id, isFollowing
      ? {
          $pull: { followers: me._id },
          $inc: { followersCount: -1 },
        }
      : {
          $addToSet: { followers: me._id },
          $inc: { followersCount: 1 },
        }
    );

    await User.findByIdAndUpdate(me._id, isFollowing
      ? {
          $pull: { following: target._id },
          $inc: { followingCount: -1 },
        }
      : {
          $addToSet: { following: target._id },
          $inc: { followingCount: 1 },
        }
    );

    res.json({ following: !isFollowing });
  } catch (e) {
    next(e);
  }
}
