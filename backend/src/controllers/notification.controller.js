import { Notification } from "../models/notification.model.js";

export async function getNotifications(req, res) {
  const notifications = await Notification.find({ to: req.user._id })
    .sort({ createdAt: -1 });

  res.json(notifications);
}

export async function markSeen(req, res) {
  await Notification.findByIdAndUpdate(req.params.id, {
    seen: true,
  });

  res.json({ seen: true });
}
