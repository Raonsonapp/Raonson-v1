import { User } from "../models/user.model.js";
import { Post } from "../models/post.model.js";
import { Reel } from "../models/reel.model.js";

/* ======================================================
   GET PROFILE (Instagram-style)
====================================================== */
export async function getProfile(req, res) {
  try {
    const username = req.params.username;

    const user = await User.findOne({ username }).select(
      "username avatar bio verified followersCount followingCount postsCount"
    );

    if (!user) return res.status(404).json({ error: "User not found" });

    const isMe = req.user.username === username;

    const [posts, reels] = await Promise.all([
      Post.find({ user: user._id })
        .select("media likes createdAt")
        .sort({ createdAt: -1 })
        .limit(30),

      Reel.find({ user: user._id })
        .select("videoUrl views likes createdAt")
        .sort({ createdAt: -1 })
        .limit(30),
    ]);

    res.json({
      user,
      isMe,
      posts,
      reels,
    });
  } catch (e) {
    res.status(500).json({ error: "Profile load failed" });
  }
}

/* ======================================================
   UPDATE PROFILE
====================================================== */
export async function updateProfile(req, res) {
  try {
    const { avatar, bio } = req.body;

    await User.findByIdAndUpdate(req.user._id, {
      avatar,
      bio,
    });

    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: "Update failed" });
  }
}
