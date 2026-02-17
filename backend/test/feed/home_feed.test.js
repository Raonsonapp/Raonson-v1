import request from "supertest";
import app from "../../src/app.js";
import { User } from "../../src/models/user.model.js";
import { Post } from "../../src/models/post.model.js";
import jwt from "jsonwebtoken";

describe("FEED / HOME FEED", () => {
  it("should return latest posts for home feed", async () => {
    const user = await User.create({
      username: "feeduser",
      email: "feed@mail.com",
      password: "hashed",
    });

    await Post.create([
      { user: user._id, caption: "post 1", media: [] },
      { user: user._id, caption: "post 2", media: [] },
    ]);

    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET);

    const res = await request(app)
      .get("/posts/feed")
      .set("Authorization", `Bearer ${token}`);

    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBeGreaterThan(0);
  });
});
