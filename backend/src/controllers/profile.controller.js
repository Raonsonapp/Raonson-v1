import { User } from "../models/user.model.js";
import { Post } from "../models/post.model.js";

export async function getProfile(req, res) {
  try {
    const user = await User.findOne({ username: req.params.username })
      .select("-password");

    if (!user) return res.status(404).json({ message: "Profile not found" });

    const posts = await Post.find({ user: user._id })
      .select("media likes commentsCount createdAt")
      .sort({ createdAt: -1 })
      .limit(30);

    res.json({ user, posts });
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Get profile failed" });
  }
}

export async function getMyProfile(req, res) {
  try {
    const user = await User.findById(req.user._id).select("-password");
    if (!user) return res.status(404).json({ message: "User not found" });

    const posts = await Post.find({ user: user._id })
      .select("media likes commentsCount createdAt")
      .sort({ createdAt: -1 })
      .limit(30);

    res.json({ user, posts });
  } catch (e) {
    res.status(500).json({ message: "Get my profile failed" });
  }
}

export async function updateProfile(req, res) {
  try {
    const allowed = ["bio", "avatar", "isPrivate", "username"];
    const updates = {};

    for (const key of allowed) {
      if (req.body[key] !== undefined) updates[key] = req.body[key];
    }

    const user = await User.findByIdAndUpdate(
      req.user._id,
      updates,
      { new: true, runValidators: true }
    ).select("-password");

    res.json(user);
  } catch (e) {
    if (e?.code === 11000) {
      return res.status(409).json({ message: "Username already taken" });
    }
    console.error(e);
    res.status(500).json({ message: "Update profile failed" });
  }
}
