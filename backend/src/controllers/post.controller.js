import { Post } from "../models/post.model.js";
import { User } from "../models/user.model.js";
import { addNotification } from "./notification.controller.js";

/* =====================================================
   CREATE POST
   ===================================================== */
export async function createPost(req, res) {
  try {
    const { caption, media } = req.body;

    if (!media || !Array.isArray(media) || media.length === 0) {
      return res.status(400).json({ error: "Media is required" });
    }

    const post = await Post.create({
      user: req.user._id,
      caption: caption || "",
      media, // [{ url, type }]
    });

    // increase posts count
    await User.findByIdAndUpdate(req.user._id, {
      $inc: { postsCount: 1 },
    });

    const populated = await post.populate(
      "user",
      "username avatar verified"
    );

    res.json(populated);
  } catch (err) {
    console.error("createPost error:", err);
    res.status(500).json({ error: "Failed to create post" });
  }
}

/* =====================================================
   GET FEED (FOLLOWING ONLY – Instagram logic)
   ===================================================== */
export async function getFeed(req, res) {
  try {
    const me = req.user._id;

    const user = await User.findById(me).select("following");

    const posts = await Post.find({
      user: { $in: user.following },
    })
      .populate("user", "username avatar verified")
      .sort({ createdAt: -1 })
      .limit(50);

    res.json(posts);
  } catch (err) {
    console.error("getFeed error:", err);
    res.status(500).json({ error: "Failed to load feed" });
  }
}

/* =====================================================
   LIKE / UNLIKE POST
   ===================================================== */
export async function toggleLike(req, res) {
  try {
    const post = await Post.findById(req.params.id);

    if (!post) {
      return res.status(404).json({ error: "Post not found" });
    }

    const userId = req.user._id;
    const liked = post.likes.includes(userId);

    if (liked) {
      post.likes.pull(userId);
    } else {
      post.likes.addToSet(userId);

      // notification (not to yourself)
      if (!post.user.equals(userId)) {
        await addNotification({
          to: post.user,
          from: userId,
          type: "like",
          postId: post._id,
        });
      }
    }

    await post.save();

    res.json({
      liked: !liked,
      likesCount: post.likes.length,
    });
  } catch (err) {
    console.error("toggleLike error:", err);
    res.status(500).json({ error: "Failed to like post" });
  }
}

/* =====================================================
   SAVE / UNSAVE POST
   ===================================================== */
export async function toggleSave(req, res) {
  try {
    const post = await Post.findById(req.params.id);

    if (!post) {
      return res.status(404).json({ error: "Post not found" });
    }

    const user = await User.findById(req.user._id);
    const saved = user.savedPosts.includes(post._id);

    if (saved) {
      user.savedPosts.pull(post._id);
    } else {
      user.savedPosts.addToSet(post._id);
    }

    await user.save();

    res.json({ saved: !saved });
  } catch (err) {
    console.error("toggleSave error:", err);
    res.status(500).json({ error: "Failed to save post" });
  }
}

/* =====================================================
   DELETE POST (OWNER ONLY)
   ===================================================== */
export async function deletePost(req, res) {
  try {
    const post = await Post.findById(req.params.id);

    if (!post) {
      return res.status(404).json({ error: "Post not found" });
    }

    if (!post.user.equals(req.user._id)) {
      return res.status(403).json({ error: "Not allowed" });
    }

    await Post.findByIdAndDelete(post._id);

    await User.findByIdAndUpdate(req.user._id, {
      $inc: { postsCount: -1 },
    });

    res.json({ success: true });
  } catch (err) {
    console.error("deletePost error:", err);
    res.status(500).json({ error: "Failed to delete post" });
  }
             }
