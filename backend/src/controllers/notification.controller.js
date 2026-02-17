import { Notification } from "../models/notification.model.js";

// GET USER NOTIFICATIONS
export async function getNotifications(req, res) {
  const userId = req.user.id;

  const notifications = await Notification.find({
    user: userId,
  })
    .sort({ createdAt: -1 })
    .limit(50);

  res.json(notifications);
}

// MARK ONE NOTIFICATION AS READ
export async function markAsRead(req, res) {
  const { id } = req.params;

  await Notification.findByIdAndUpdate(id, {
    $set: { read: true },
  });

  res.json({ read: true });
}

// MARK ALL AS READ
export async function markAllAsRead(req, res) {
  const userId = req.user.id;

  await Notification.updateMany(
    { user: userId, read: false },
    { $set: { read: true } }
  );

  res.json({ success: true });
}

// DELETE NOTIFICATION
export async function deleteNotification(req, res) {
  const { id } = req.params;

  await Notification.findByIdAndDelete(id);

  res.json({ deleted: true });
    }
