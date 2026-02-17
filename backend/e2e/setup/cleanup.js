import mongoose from "mongoose";
import { User } from "../../src/models/user.model.js";
import { Post } from "../../src/models/post.model.js";
import { Comment } from "../../src/models/comment.model.js";
import { Notification } from "../../src/models/notification.model.js";

export async function cleanupDatabase() {
  await Promise.all([
    User.deleteMany({}),
    Post.deleteMany({}),
    Comment.deleteMany({}),
    Notification.deleteMany({}),
  ]);
}

export async function closeDatabase() {
  if (mongoose.connection.readyState === 1) {
    await mongoose.disconnect();
  }
}
