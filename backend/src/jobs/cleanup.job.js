import { Notification } from "../models/notification.model.js";
import { Story } from "../models/story.model.js";

export async function runCleanupJob() {
  const now = new Date();

  // ❌ Delete read notifications older than 30 days
  await Notification.deleteMany({
    read: true,
    createdAt: { $lt: new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000) },
  });

  // ❌ Remove orphan stories without user (data integrity)
  await Story.deleteMany({ user: { $exists: false } });

  return { status: "cleanup_completed" };
}
