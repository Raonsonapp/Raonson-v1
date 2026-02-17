import { Queue } from "bullmq";
import { redisConfig } from "../config/redis.config.js";
import { Notification } from "../models/notification.model.js";

export const notificationQueue = new Queue("notification-queue", {
  connection: redisConfig,
});

export async function enqueueNotification(payload) {
  const { to, from, type, entityId } = payload;

  await notificationQueue.add("push-notification", {
    to,
    from,
    type,
    entityId,
  });

  await Notification.create({
    to,
    from,
    type,
    entityId,
    read: false,
  });
}
