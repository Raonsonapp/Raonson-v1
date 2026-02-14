import { v4 as uuid } from "uuid";

export const reels = [
  {
    id: uuid(),
    user: {
      id: "u1",
      username: "olivia_martin",
      avatar: "https://i.pravatar.cc/150?img=5",
    },
    videoUrl:
      "https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4",
    caption: "Sunset vibes 🌅 #beachlife",
    likes: 0,
    comments: 0,
    views: 0,
    createdAt: Date.now(),
  },
];
