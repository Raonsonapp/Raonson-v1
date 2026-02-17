import { Reel } from "../../src/models/reel.model.js";
import { User } from "../../src/models/user.model.js";

describe("REELS / ALGORITHM FEED", () => {
  it("should prioritize reels with higher engagement", async () => {
    const user = await User.create({
      username: "algo",
      email: "algo@mail.com",
      password: "hashed",
    });

    const low = await Reel.create({
      user: user._id,
      videoUrl: "https://cdn.test/low.mp4",
      likes: [],
      views: 10,
    });

    const high = await Reel.create({
      user: user._id,
      videoUrl: "https://cdn.test/high.mp4",
      likes: [user._id],
      views: 100,
    });

    const feed = await Reel.find().sort({
      views: -1,
      "likes.length": -1,
      createdAt: -1,
    });

    expect(feed[0]._id.toString()).toBe(high._id.toString());
  });
});
