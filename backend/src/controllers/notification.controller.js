import { notifications } from "../data/notifications.store.js";

export const addNotification = ({ to, from, type, postId }) => {
  notifications.unshift({
    id: Date.now().toString(),
    to,
    from,
    type, // like | comment | follow
    postId,
    seen: false,
    createdAt: new Date(),
  });
};

export const getNotifications = (req, res) => {
  const { user } = req.query;
  const list = notifications.filter(n => n.to === user);
  res.json(list);
};

export const markSeen = (req, res) => {
  const { id } = req.params;
  const n = notifications.find(n => n.id === id);
  if (n) n.seen = true;
  res.json({ ok: true });
};
