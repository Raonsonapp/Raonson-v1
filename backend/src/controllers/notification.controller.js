import { notifications } from "../data/notifications.store.js";

// GET notifications for user
export const getNotifications = (req, res) => {
  const user = req.query.user || "raonson";

  const list = notifications
    .filter(n => n.to === user)
    .sort((a, b) => b.createdAt - a.createdAt);

  res.json(list);
};

// MARK ALL AS SEEN
export const markSeen = (req, res) => {
  const user = req.body.user || "raonson";

  notifications.forEach(n => {
    if (n.to === user) n.seen = true;
  });

  res.json({ success: true });
};

// INTERNAL: add notification
export const addNotification = ({ to, from, type, postId }) => {
  notifications.push({
    id: Date.now().toString(),
    to,
    from,
    type, // like | follow | comment
    postId,
    seen: false,
    createdAt: new Date(),
  });
};
