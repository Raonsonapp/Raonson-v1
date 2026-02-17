import { Notification } from "../models/notification.model.js";

export async function createNotification({
  to,
  from,
  type,
  targetId = null,
}) {
  return Notification.create({
    to,
    from,
    type,
    targetId,
  });
}

export async function getNotifications(userId) {
  return Notification.find({ to: userId })
    .populate("from", "username avatar verified")
    .sort({ createdAt: -1 })
    .limit(50);
}

export async function markSeen(notificationId) {
  await Notification.findByIdAndUpdate(notificationId, {
    seen: true,
  });
}
