import { Notification } from "../models/notification.model.js";

export async function getNotifications(req, res) {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 30;
    const skip = (page - 1) * limit;

    const notifications = await Notification.find({ user: req.user._id })
      .populate("fromUser", "username avatar verified")
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit);

    const unreadCount = await Notification.countDocuments({ user: req.user._id, read: false });

    res.json({ notifications, unreadCount, page, limit });
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Get notifications failed" });
  }
}

export async function markAsRead(req, res) {
  try {
    await Notification.findByIdAndUpdate(req.params.id, { $set: { read: true } });
    res.json({ read: true });
  } catch (e) {
    res.status(500).json({ message: "Mark read failed" });
  }
}

export async function markAllAsRead(req, res) {
  try {
    await Notification.updateMany(
      { user: req.user._id, read: false },
      { $set: { read: true } }
    );
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ message: "Mark all read failed" });
  }
}

export async function deleteNotification(req, res) {
  try {
    await Notification.findByIdAndDelete(req.params.id);
    res.json({ deleted: true });
  } catch (e) {
    res.status(500).json({ message: "Delete notification failed" });
  }
}
