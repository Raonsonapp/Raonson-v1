import { Queue } from "bullmq";
import { redisConfig } from "../config/redis.config.js";

export const mediaQueue = new Queue("media-queue", {
  connection: redisConfig,
});

export async function enqueueMediaJob({ mediaUrl, mediaType, owner }) {
  await mediaQueue.add("process-media", {
    mediaUrl,
    mediaType,
    owner,
  });
}
