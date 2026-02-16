import { User } from "../models/user.model.js";
import { Post } from "../models/post.model.js";
import { Reel } from "../models/reel.model.js";

/* =====================================================
   GET PROFILE
   ===================================================== */
export async function getProfile(req, res) {
  try {
    const viewerId = req.user._id;
    const username = req.params.username;

    const user = await User.findOne({ username })
      .select("-password")
      .populate("followers", "_id")
      .populate("following", "_id");

    if (!user) {
      return res.status(404).json({ error: "User not found" });
    }

    const isOwner = user._id.equals(viewerId);
    const isFollowing = user.followers.some(f =>
      f._id.equals(viewerId)
    );
    const isRequested = user.followRequests?.includes(viewerId);

    const canViewContent =
      !user.private || isOwner || isFollowing;

    let posts = [];
    let reels = [];

    if (canViewContent) {
      posts = await Post.find({ user: user._id })
        .sort({ createdAt: -1 })
        .select("media createdAt");

      reels = await Reel.find({ user: user._id })
        .sort({ createdAt: -1 });
    }

    res.json({
      user: {
        id: user._id,
        username: user.username,
        avatar: user.avatar,
        verified: user.verified,
        private: user.private,
      },
      stats: {
        posts: user.postsCount,
        followers: user.followers.length,
        following: user.following.length,
      },
      relationship: {
        isOwner,
        isFollowing,
        isRequested,
      },
      posts,
      reels,
    });
  } catch (err) {
    console.error("getProfile error:", err);
    res.status(500).json({ error: "Failed to load profile" });
  }
      }
