import { User } from "../models/user.model.js";
import { Post } from "../models/post.model.js";
import { Reel } from "../models/reel.model.js";

export async function search(req, res) {
  try {
    const q = req.query.q?.trim();
    if (!q || q.length < 1) {
      return res.status(400).json({ message: "Query required" });
    }

    const regex = { $regex: q, $options: "i" };

    const [users, posts, reels] = await Promise.all([
      User.find({ username: regex })
        .select("username avatar verified bio followersCount")
        .limit(20),
      Post.find({ caption: regex })
        .populate("user", "username avatar verified")
        .select("caption media likes commentsCount createdAt")
        .limit(20),
      Reel.find({ caption: regex })
        .populate("user", "username avatar verified")
        .select("caption videoUrl likes views createdAt")
        .limit(10),
    ]);

    res.json({ users, posts, reels });
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Search failed" });
  }
}

export async function searchUsers(req, res) {
  try {
    const q = req.query.q?.trim();
    if (!q) return res.status(400).json({ message: "Query required" });

    const users = await User.find({
      username: { $regex: q, $options: "i" },
    })
      .select("username avatar verified bio followersCount")
      .limit(30);

    res.json(users);
  } catch (e) {
    res.status(500).json({ message: "Search users failed" });
  }
}
