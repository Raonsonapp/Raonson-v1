import { Notification } from "../models/notification.model.js";
import { emitToUser } from "../socket/index.js";

export async function getNotifications(req, res) {
  const items = await Notification.find({ to: req.user._id })
    .populate("from", "username avatar")
    .sort({ createdAt: -1 });

  res.json(items);
}

export async function createNotification({
  to,
  from,
  type,
  post,
  story,
}) {
  const n = await Notification.create({
    to,
    from,
    type,
    post,
    story,
  });

  emitToUser(to, "notification", n);
}

export async function markSeen(req, res) {
  await Notification.findByIdAndUpdate(req.params.id, {
    seen: true,
  });
  res.json({ ok: true });
}
