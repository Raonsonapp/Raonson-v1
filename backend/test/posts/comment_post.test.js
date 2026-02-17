import request from "supertest";
import app from "../../src/app.js";
import { User } from "../../src/models/user.model.js";
import { Post } from "../../src/models/post.model.js";
import jwt from "jsonwebtoken";

describe("POSTS / COMMENT POST", () => {
  it("should add comment to post", async () => {
    const user = await User.create({
      username: "commenter",
      email: "comment@mail.com",
      password: "hashed",
    });

    const post = await Post.create({
      caption: "comment here",
      media: [],
      user: user._id,
    });

    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET);

    const res = await request(app)
      .post(`/comments/${post._id}`)
      .set("Authorization", `Bearer ${token}`)
      .send({ text: "Nice post" });

    expect(res.statusCode).toBe(200);
    expect(res.body.text).toBe("Nice post");
  });
});
