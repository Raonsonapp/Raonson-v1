import app from "./app.js";

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log("Raonson backend running on port", PORT);
});
const notifications = [
  { id: 1, text: "Someone liked your post ❤️", time: "1m ago" },
  { id: 2, text: "New follower 👤", time: "5m ago" }
];

app.get("/notifications", (req, res) => {
  res.json(notifications);
});
