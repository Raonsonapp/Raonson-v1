import request from "supertest";
import app from "../../src/app.js";
import { User } from "../../src/models/user.model.js";
import { Post } from "../../src/models/post.model.js";
import jwt from "jsonwebtoken";

describe("POSTS / LIKE POST", () => {
  it("should like a post", async () => {
    const user = await User.create({
      username: "liker",
      email: "like@mail.com",
      password: "hashed",
    });

    const post = await Post.create({
      caption: "like me",
      media: [],
      user: user._id,
    });

    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET);

    const res = await request(app)
      .post(`/posts/${post._id}/like`)
      .set("Authorization", `Bearer ${token}`);

    expect(res.statusCode).toBe(200);
    expect(res.body.liked).toBe(true);
  });
});
