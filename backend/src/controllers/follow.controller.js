import {
  followUser,
  unfollowUser,
  acceptFollow,
  rejectFollow,
} from "../services/follow.service.js";

export async function follow(req, res, next) {
  try {
    const result = await followUser({
      fromUser: req.user,
      toUserId: req.params.id,
    });
    res.json(result);
  } catch (e) {
    next(e);
  }
}

export async function unfollow(req, res, next) {
  try {
    const result = await unfollowUser({
      fromUser: req.user,
      toUserId: req.params.id,
    });
    res.json(result);
  } catch (e) {
    next(e);
  }
}

export async function accept(req, res, next) {
  try {
    const result = await acceptFollow({
      user: req.user,
      fromUserId: req.params.id,
    });
    res.json(result);
  } catch (e) {
    next(e);
  }
}

export async function reject(req, res, next) {
  try {
    const result = await rejectFollow({
      user: req.user,
      fromUserId: req.params.id,
    });
    res.json(result);
  } catch (e) {
    next(e);
  }
}
