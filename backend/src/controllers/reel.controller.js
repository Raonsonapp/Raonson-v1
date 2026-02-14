import Reel from "../models/reel.model.js";

/* CREATE REEL */
export const createReel = async (req, res) => {
  const { videoUrl, caption } = req.body;

  if (!videoUrl) {
    return res.status(400).json({ error: "videoUrl required" });
  }

  const reel = await Reel.create({
    userId: req.user.id,
    videoUrl,
    caption,
  });

  res.json(reel);
};

/* GET REELS FEED */
export const getReels = async (req, res) => {
  const reels = await Reel.find()
    .sort({ createdAt: -1 })
    .limit(20);

  res.json(
    reels.map((r) => ({
      id: r._id,
      videoUrl: r.videoUrl,
      caption: r.caption,
      likes: r.likesCount,
      comments: r.commentsCount,
      views: r.viewsCount,
      liked: false, // Flutter худаш месанҷад
    }))
  );
};

/* ADD VIEW */
export const addView = async (req, res) => {
  await Reel.findByIdAndUpdate(req.params.reelId, {
    $inc: { viewsCount: 1 },
  });

  res.json({ viewed: true });
};

/* ❤️ TOGGLE LIKE (ЗИНДА) */
export const toggleLike = async (req, res) => {
  const { reelId } = req.params;
  const userId = req.user.id;

  const reel = await Reel.findById(reelId);
  if (!reel) return res.status(404).json({ error: "Reel not found" });

  const index = reel.likedBy.indexOf(userId);

  if (index === -1) {
    reel.likedBy.push(userId);
    reel.likesCount += 1;
  } else {
    reel.likedBy.splice(index, 1);
    reel.likesCount -= 1;
  }

  await reel.save();

  res.json({
    likes: reel.likesCount,
    liked: index === -1,
  });
};

/* 💬 ADD COMMENT (COUNTER) */
export const addComment = async (req, res) => {
  await Reel.findByIdAndUpdate(req.params.reelId, {
    $inc: { commentsCount: 1 },
  });

  res.json({ commented: true });
};
