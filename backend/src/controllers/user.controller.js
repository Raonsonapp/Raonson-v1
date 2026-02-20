import { User } from "../models/user.model.js";
import { Post } from "../models/post.model.js";
import { Reel } from "../models/reel.model.js";

export async function getUserById(req, res) {
  try {
    const user = await User.findById(req.params.id).select("-password");
    if (!user) return res.status(404).json({ message: "User not found" });
    res.json(user);
  } catch (e) {
    res.status(500).json({ message: "Get user failed" });
  }
}

export async function updateUser(req, res) {
  try {
    const allowed = ["bio", "avatar", "isPrivate", "username"];
    const updates = {};
    for (const key of allowed) {
      if (req.body[key] !== undefined) updates[key] = req.body[key];
    }

    const user = await User.findByIdAndUpdate(req.user._id, updates, {
      new: true,
      runValidators: true,
    }).select("-password");

    res.json(user);
  } catch (e) {
    if (e?.code === 11000) return res.status(409).json({ message: "Username taken" });
    res.status(500).json({ message: "Update user failed" });
  }
}

export async function deleteUser(req, res) {
  try {
    await User.findByIdAndDelete(req.user._id);
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ message: "Delete user failed" });
  }
}

// ✅ GET /users/:id/posts  → lib мефиристад
export async function getUserPosts(req, res) {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 24;
    const skip = (page - 1) * limit;

    const posts = await Post.find({ user: req.params.id })
      .select("media likes commentsCount createdAt")
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit);

    res.json(posts);
  } catch (e) {
    res.status(500).json({ message: "Get user posts failed" });
  }
}

// ✅ GET /users/:id/reels  → lib мефиристад
export async function getUserReels(req, res) {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 24;
    const skip = (page - 1) * limit;

    const reels = await Reel.find({ user: req.params.id })
      .select("videoUrl caption likes views createdAt")
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit);

    res.json(reels);
  } catch (e) {
    res.status(500).json({ message: "Get user reels failed" });
  }
}
