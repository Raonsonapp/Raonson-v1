import { User } from "../models/user.model.js";

export async function getProfile(req, res) {
  const user = await User.findOne({ username: req.params.username })
    .select("-password");

  if (!user) {
    return res.status(404).json({ message: "Profile not found" });
  }

  res.json(user);
}

export async function updateProfile(req, res) {
  const updates = req.body;

  const user = await User.findByIdAndUpdate(
    req.user._id,
    updates,
    { new: true }
  ).select("-password");

  res.json(user);
}
