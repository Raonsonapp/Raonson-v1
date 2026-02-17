import { Story } from "../../src/models/story.model.js";
import { User } from "../../src/models/user.model.js";

describe("STORIES / EXPIRE", () => {
  it("should not return expired stories (older than 24h)", async () => {
    const user = await User.create({
      username: "expireuser",
      email: "expire@mail.com",
      password: "hashed",
    });

    const expiredDate = new Date(Date.now() - 25 * 60 * 60 * 1000);

    await Story.create({
      user: user._id,
      mediaUrl: "https://cdn.test/old.jpg",
      mediaType: "image",
      createdAt: expiredDate,
    });

    const activeStories = await Story.find({
      createdAt: { $gte: new Date(Date.now() - 24 * 60 * 60 * 1000) },
    });

    expect(activeStories.length).toBe(0);
  });
});
