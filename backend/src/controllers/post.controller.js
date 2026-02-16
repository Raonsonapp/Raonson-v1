import { Post } from "../models/post.model.js";
import { User } from "../models/user.model.js";
import { Follow } from "../models/follow.model.js";
import { addNotification } from "./notification.controller.js";

/* ======================================================
   CREATE POST
====================================================== */
export async function createPost(req, res) {
  try {
    const { caption = "", media = [] } = req.body;

    if (!media.length) {
      return res.status(400).json({ error: "Media is required" });
    }

    const post = await Post.create({
      user: req.user._id,
      caption,
      media,
      likes: [],
      saves: [],
    });

    await User.findByIdAndUpdate(req.user._id, {
      $inc: { postsCount: 1 },
    });

    const populated = await post.populate(
      "user",
      "username avatar verified"
    );

    res.json(populated);
  } catch (err) {
    console.error("CREATE POST ERROR:", err);
    res.status(500).json({ error: "Failed to create post" });
  }
}

/* ======================================================
   GET FEED (Instagram-style)
   - my posts
   - following posts
====================================================== */
export async function getFeed(req, res) {
  try {
    const myId = req.user._id;

    // users I follow
    const following = await Follow.find({ from: myId }).select("to");

    const userIds = following.map(f => f.to);
    userIds.push(myId); // include my posts

    const posts = await Post.find({ user: { $in: userIds } })
      .populate("user", "username avatar verified")
      .sort({ createdAt: -1 })
      .limit(50)
      .lean();

    res.json(posts);
  } catch (err) {
    console.error("GET FEED ERROR:", err);
    res.status(500).json({ error: "Failed to load feed" });
  }
}

/* ======================================================
   LIKE / UNLIKE POST
====================================================== */
export async function toggleLike(req, res) {
  try {
    const post = await Post.findById(req.params.id);
    if (!post) {
      return res.status(404).json({ error: "Post not found" });
    }

    const userId = req.user._id;
    const liked = post.likes.includes(userId);

    await Post.findByIdAndUpdate(
      post._id,
      liked
        ? { $pull: { likes: userId } }
        : { $addToSet: { likes: userId } }
    );

    // 🔔 notification
    if (!liked && post.user.toString() !== userId.toString()) {
      addNotification({
        to: post.user,
        from: userId,
        type: "like",
        postId: post._id,
      });
    }

    res.json({ liked: !liked });
  } catch (err) {
    console.error("LIKE ERROR:", err);
    res.status(500).json({ error: "Failed to like post" });
  }
}

/* ======================================================
   SAVE / UNSAVE POST
====================================================== */
export async function toggleSave(req, res) {
  try {
    const post = await Post.findById(req.params.id);
    if (!post) {
      return res.status(404).json({ error: "Post not found" });
    }

    const userId = req.user._id;
    const saved = post.saves.includes(userId);

    await Post.findByIdAndUpdate(
      post._id,
      saved
        ? { $pull: { saves: userId } }
        : { $addToSet: { saves: userId } }
    );

    res.json({ saved: !saved });
  } catch (err) {
    console.error("SAVE ERROR:", err);
    res.status(500).json({ error: "Failed to save post" });
  }
}
