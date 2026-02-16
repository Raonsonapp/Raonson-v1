import { getProfile } from "../services/profile.service.js";

export async function viewProfile(req, res, next) {
  try {
    const { username } = req.params;

    const data = await getProfile({
      viewerId: req.user._id,
      username,
    });

    res.json(data);
  } catch (e) {
    next(e);
  }
}
