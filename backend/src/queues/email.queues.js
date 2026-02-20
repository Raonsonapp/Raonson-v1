import { Queue } from "bullmq";
import { redisConfig } from "../config/redis.config.js";

export const emailQueue = new Queue("email-queue", {
  connection: redisConfig,
});

export async function enqueueEmail({ to, subject, body }) {
  await emailQueue.add("send-email", {
    to,
    subject,
    body,
  });
}
