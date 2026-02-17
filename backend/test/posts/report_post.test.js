import request from "supertest";
import app from "../../src/app.js";
import { User } from "../../src/models/user.model.js";
import { Post } from "../../src/models/post.model.js";
import jwt from "jsonwebtoken";

describe("POSTS / REPORT POST", () => {
  it("should report a post", async () => {
    const user = await User.create({
      username: "reporter",
      email: "report@mail.com",
      password: "hashed",
    });

    const post = await Post.create({
      caption: "bad post",
      media: [],
      user: user._id,
    });

    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET);

    const res = await request(app)
      .post(`/posts/${post._id}/report`)
      .set("Authorization", `Bearer ${token}`)
      .send({ reason: "spam" });

    expect(res.statusCode).toBe(200);
    expect(res.body.reported).toBe(true);
  });
});
