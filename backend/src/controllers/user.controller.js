import { User } from "../models/user.model.js";

export async function getUserById(req, res) {
  const user = await User.findById(req.params.id)
    .select("-password");

  if (!user) {
    return res.status(404).json({ message: "User not found" });
  }

  res.json(user);
}

export async function updateUser(req, res) {
  const updates = req.body;

  const user = await User.findByIdAndUpdate(
    req.user._id,
    updates,
    { new: true }
  ).select("-password");

  res.json(user);
}

export async function deleteUser(req, res) {
  await User.findByIdAndDelete(req.user._id);
  res.json({ success: true });
}
