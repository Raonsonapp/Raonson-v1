import mongoose from "mongoose";
import bcrypt from "bcryptjs";
import { User } from "../../src/models/user.model.js";
import { Post } from "../../src/models/post.model.js";

export async function seedDatabase() {
  await User.deleteMany({});
  await Post.deleteMany({});

  const passwordHash = await bcrypt.hash("password123", 10);

  const user = await User.create({
    username: "e2e_user",
    avatar: "",
    verified: false,
    password: passwordHash,
  });

  await Post.create({
    user: user._id,
    caption: "E2E test post",
    media: [
      {
        url: "https://example.com/image.jpg",
        type: "image",
      },
    ],
  });

  return { user };
}
