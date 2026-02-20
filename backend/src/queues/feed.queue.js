import { Queue } from "bullmq";
import { redisConfig } from "../config/redis.config.js";
import { User } from "../models/user.model.js";

export const feedQueue = new Queue("feed-queue", {
  connection: redisConfig,
});

export async function enqueueFeedUpdate({ postId, authorId }) {
  const author = await User.findById(authorId).select("followers");

  for (const followerId of author.followers) {
    await feedQueue.add("fanout-feed", {
      postId,
      userId: followerId,
    });
  }
}
