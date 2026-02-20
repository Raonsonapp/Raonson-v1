import { User } from "../models/user.model.js";

export async function followUser(req, res) {
  try {
    const targetId = req.params.id;
    const userId = req.user._id.toString();

    if (targetId === userId) {
      return res.status(400).json({ message: "Cannot follow yourself" });
    }

    const target = await User.findById(targetId);
    if (!target) return res.status(404).json({ message: "User not found" });

    // Already following?
    if (target.followers.includes(userId)) {
      return res.json({ following: true });
    }

    if (target.isPrivate) {
      if (!target.followRequests.includes(userId)) {
        target.followRequests.push(userId);
        await target.save();
      }
      return res.json({ requested: true });
    }

    await User.findByIdAndUpdate(targetId, {
      $addToSet: { followers: userId },
      $inc: { followersCount: 1 },
    });
    await User.findByIdAndUpdate(userId, {
      $addToSet: { following: targetId },
      $inc: { followingCount: 1 },
    });

    res.json({ following: true });
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Follow failed" });
  }
}

export async function unfollowUser(req, res) {
  try {
    const targetId = req.params.id;
    const userId = req.user._id.toString();

    await User.findByIdAndUpdate(targetId, {
      $pull: { followers: userId },
      $inc: { followersCount: -1 },
    });
    await User.findByIdAndUpdate(userId, {
      $pull: { following: targetId },
      $inc: { followingCount: -1 },
    });

    res.json({ following: false });
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Unfollow failed" });
  }
}

export async function acceptRequest(req, res) {
  try {
    const requesterId = req.params.id;
    const userId = req.user._id.toString();

    await User.findByIdAndUpdate(userId, {
      $pull: { followRequests: requesterId },
      $addToSet: { followers: requesterId },
      $inc: { followersCount: 1 },
    });
    await User.findByIdAndUpdate(requesterId, {
      $addToSet: { following: userId },
      $inc: { followingCount: 1 },
    });

    res.json({ accepted: true });
  } catch (e) {
    res.status(500).json({ message: "Accept request failed" });
  }
}

export async function rejectRequest(req, res) {
  try {
    const requesterId = req.params.id;
    const userId = req.user._id.toString();

    await User.findByIdAndUpdate(userId, {
      $pull: { followRequests: requesterId },
    });

    res.json({ rejected: true });
  } catch (e) {
    res.status(500).json({ message: "Reject request failed" });
  }
}

export async function getFollowers(req, res) {
  try {
    const user = await User.findById(req.params.id)
      .populate("followers", "username avatar verified");
    if (!user) return res.status(404).json({ message: "User not found" });

    res.json(user.followers);
  } catch (e) {
    res.status(500).json({ message: "Get followers failed" });
  }
}

export async function getFollowing(req, res) {
  try {
    const user = await User.findById(req.params.id)
      .populate("following", "username avatar verified");
    if (!user) return res.status(404).json({ message: "User not found" });

    res.json(user.following);
  } catch (e) {
    res.status(500).json({ message: "Get following failed" });
  }
}
