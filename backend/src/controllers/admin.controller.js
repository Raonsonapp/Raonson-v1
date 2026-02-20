import { User } from "../models/user.model.js";
import { Post } from "../models/post.model.js";
import { Reel } from "../models/reel.model.js";
import { Story } from "../models/story.model.js";
import { Notification } from "../models/notification.model.js";

// ==========================
// ADMIN DASHBOARD STATS
// ==========================
export async function getStats(req, res) {
  const [
    users,
    posts,
    reels,
    stories,
    notifications,
  ] = await Promise.all([
    User.countDocuments(),
    Post.countDocuments(),
    Reel.countDocuments(),
    Story.countDocuments(),
    Notification.countDocuments(),
  ]);

  res.json({
    users,
    posts,
    reels,
    stories,
    notifications,
  });
}

// ==========================
// BAN USER
// ==========================
export async function banUser(req, res) {
  const { id } = req.params;

  await User.findByIdAndUpdate(id, {
    $set: { banned: true },
  });

  res.json({ banned: true });
}

// ==========================
// UNBAN USER
// ==========================
export async function unbanUser(req, res) {
  const { id } = req.params;

  await User.findByIdAndUpdate(id, {
    $set: { banned: false },
  });

  res.json({ banned: false });
    }
