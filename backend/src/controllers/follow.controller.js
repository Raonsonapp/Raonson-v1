import {
  followUser,
  unfollowUser,
  acceptRequest,
  rejectRequest,
} from "../services/follow.service.js";

export async function follow(req, res, next) {
  try {
    const result = await followUser({
      from: req.user._id,
      to: req.params.id,
    });
    res.json(result);
  } catch (e) {
    next(e);
  }
}

export async function unfollow(req, res, next) {
  try {
    await unfollowUser({
      from: req.user._id,
      to: req.params.id,
    });
    res.json({ ok: true });
  } catch (e) {
    next(e);
  }
}

export async function accept(req, res, next) {
  try {
    const r = await acceptRequest({
      owner: req.user._id,
      from: req.params.id,
    });
    res.json(r);
  } catch (e) {
    next(e);
  }
}

export async function reject(req, res, next) {
  try {
    await rejectRequest({
      owner: req.user._id,
      from: req.params.id,
    });
    res.json({ ok: true });
  } catch (e) {
    next(e);
  }
}
