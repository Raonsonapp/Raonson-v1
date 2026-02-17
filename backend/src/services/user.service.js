import { User } from "../models/user.model.js";

export async function getUserById(userId) {
  return User.findById(userId)
    .select("username avatar verified followersCount followingCount postsCount");
}

export async function updateAvatar(userId, avatarUrl) {
  return User.findByIdAndUpdate(
    userId,
    { avatar: avatarUrl },
    { new: true }
  );
}
