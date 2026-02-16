import { User } from "../models/user.model.js";
import { Post } from "../models/post.model.js";

// ================= PROFILE INFO =================
export async function getProfile(req, res, next) {
  try {
    const { username } = req.params;
    const viewerId = req.user._id;

    const user = await User.findOne({ username })
      .select(
        "username avatar verified isPrivate postsCount followersCount followingCount followers followRequests"
      );

    if (!user) return res.status(404).json({ error: "User not found" });

    const isOwner = user._id.equals(viewerId);
    const isFollowing = user.followers.includes(viewerId);
    const isRequested = user.followRequests.includes(viewerId);

    let access = "public";
    if (user.isPrivate && !isOwner && !isFollowing) {
      access = isRequested ? "requested" : "private";
    }

    res.json({
      user: {
        id: user._id,
        username: user.username,
        avatar: user.avatar,
        verified: user.verified,
        postsCount: user.postsCount,
        followersCount: user.followersCount,
        followingCount: user.followingCount,
      },
      relationship: {
        isOwner,
        isFollowing,
        isRequested,
        access,
      },
    });
  } catch (e) {
    next(e);
  }
}

// ================= PROFILE POSTS =================
export async function getProfilePosts(req, res, next) {
  try {
    const { username } = req.params;
    const { cursor, limit } = req.query;

    const viewerId = req.user._id;

    const user = await User.findOne({ username })
      .select("isPrivate followers");

    if (!user) return res.status(404).json({ error: "User not found" });

    const isOwner = user._id.equals(viewerId);
    const isFollowing = user.followers.includes(viewerId);

    if (user.isPrivate && !isOwner && !isFollowing) {
      return res.status(403).json({ error: "Private profile" });
    }

    const query = { user: user._id };
    if (cursor) query.createdAt = { $lt: new Date(cursor) };

    const posts = await Post.find(query)
      .sort({ createdAt: -1 })
      .limit(Number(limit) || 12)
      .select("media createdAt");

    res.json({
      items: posts,
      nextCursor:
        posts.length > 0
          ? posts[posts.length - 1].createdAt
          : null,
    });
  } catch (e) {
    next(e);
  }
}
