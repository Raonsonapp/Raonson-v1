import request from "supertest";
import app from "../../src/app.js";
import { User } from "../../src/models/user.model.js";
import { Post } from "../../src/models/post.model.js";
import jwt from "jsonwebtoken";

describe("FEED / FILTERS", () => {
  it("should filter feed by media type", async () => {
    const user = await User.create({
      username: "filteruser",
      email: "filter@mail.com",
      password: "hashed",
    });

    await Post.create([
      {
        user: user._id,
        caption: "image post",
        media: [{ url: "img.jpg", type: "image" }],
      },
      {
        user: user._id,
        caption: "video post",
        media: [{ url: "vid.mp4", type: "video" }],
      },
    ]);

    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET);

    const res = await request(app)
      .get("/posts/feed?type=video")
      .set("Authorization", `Bearer ${token}`);

    expect(res.statusCode).toBe(200);
    expect(
      res.body.every(p => p.media.some(m => m.type === "video"))
    ).toBe(true);
  });
});
