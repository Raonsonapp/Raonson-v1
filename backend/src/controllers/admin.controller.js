import { User } from "../models/user.model.js";

export async function verifyUser(req, res) {
  await User.findByIdAndUpdate(req.params.userId, {
    verified: true,
  });

  res.json({ verified: true });
}

export async function banUser(req, res) {
  await User.findByIdAndDelete(req.params.userId);
  res.json({ banned: true });
}
