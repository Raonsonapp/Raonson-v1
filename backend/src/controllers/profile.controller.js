import { User } from "../models/user.model.js";
import { Post } from "../models/post.model.js";

export async function getProfile(req, res) {
  try {
    let user = await User.findOne({ username: req.params.username })
      .select("-password");

    if (!user) return res.status(404).json({ message: "Profile not found" });

    // Auto-clear expired note
    if (user.noteExpiresAt && user.noteExpiresAt < new Date()) {
      user = await User.findByIdAndUpdate(
        user._id,
        { note: "", noteSong: { title: "", artist: "", artUrl: "", previewUrl: "", trackMs: 0, startMs: 0, endMs: 30000 }, noteExpiresAt: null },
        { new: true }
      ).select("-password");
    }

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
    let user = await User.findById(req.user._id).select("-password");
    if (!user) return res.status(404).json({ message: "User not found" });

    // Auto-clear expired note
    if (user.noteExpiresAt && user.noteExpiresAt < new Date()) {
      user = await User.findByIdAndUpdate(
        req.user._id,
        { note: "", noteSong: { title: "", artist: "", artUrl: "", previewUrl: "", trackMs: 0, startMs: 0, endMs: 30000 }, noteExpiresAt: null },
        { new: true }
      ).select("-password");
    }

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

// ── Ёддошт гузоштан (матн + мусиқӣ) ──
export async function setNote(req, res) {
  try {
    const { note, song } = req.body;
    const text = (note || '').trim().slice(0, 60);

    // song = { title, artist, artUrl } or null
    const noteSong = song && (song.title || song.artist)
      ? { title: song.title || '', artist: song.artist || '', artUrl: song.artUrl || '', previewUrl: song.previewUrl || '', trackMs: song.trackMs || 0, startMs: song.startMs || 0, endMs: song.endMs || 30000 }
      : { title: '', artist: '', artUrl: '' };

    // Expires only if there's content
    const hasContent = text || noteSong.title;
    const noteExpiresAt = hasContent ? new Date(Date.now() + 24 * 60 * 60 * 1000) : null;

    const user = await User.findByIdAndUpdate(
      req.user._id,
      { note: text, noteSong, noteExpiresAt },
      { new: true }
    ).select('note noteSong noteExpiresAt');

    res.json({ note: user.note, noteSong: user.noteSong, noteExpiresAt: user.noteExpiresAt });
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: 'Set note failed' });
  }
}

// ── Ёддоштҳои дӯстон (барои chat list) ──
export async function getFriendsNotes(req, res) {
  try {
    const me = await User.findById(req.user._id).select('following');
    const friendIds = me.following || [];

    const now = new Date();
    const friends = await User.find({
      _id: { $in: friendIds },
      noteExpiresAt: { $gt: now },
      $or: [
        { note: { $ne: '' } },
        { 'noteSong.title': { $ne: '' } },
      ],
    }).select('_id username avatar note noteSong noteExpiresAt verified');

    res.json({ notes: friends });
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: 'Get notes failed' });
  }
  }
