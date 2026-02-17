import request from "supertest";
import app from "../../src/app.js";
import { User } from "../../src/models/user.model.js";
import { Post } from "../../src/models/post.model.js";
import jwt from "jsonwebtoken";

describe("FEED / PAGINATION", () => {
  it("should paginate feed results", async () => {
    const user = await User.create({
      username: "pageuser",
      email: "page@mail.com",
      password: "hashed",
    });

    for (let i = 0; i < 15; i++) {
      await Post.create({
        user: user._id,
        caption: `post ${i}`,
        media: [],
      });
    }

    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET);

    const res = await request(app)
      .get("/posts/feed?page=1&limit=5")
      .set("Authorization", `Bearer ${token}`);

    expect(res.statusCode).toBe(200);
    expect(res.body.length).toBe(5);
  });
});
