import { Like } from "../models/like.model.js";

export async function likeTarget(req, res) {
  const { targetId, targetType } = req.body;

  const like = await Like.create({
    user: req.user.id,
    targetId,
    targetType,
  });

  res.json({ success: true, like });
}

export async function unlikeTarget(req, res) {
  const { targetId } = req.body;

  await Like.deleteOne({
    user: req.user.id,
    targetId,
  });

  res.json({ success: true });
}

export async function getLikes(req, res) {
  const { targetId } = req.params;

  const likes = await Like.countDocuments({ targetId });

  res.json({ likes });
    }
