import request from "supertest";
import app from "../../src/app.js";
import { User } from "../../src/models/user.model.js";
import { Post } from "../../src/models/post.model.js";
import jwt from "jsonwebtoken";

describe("POSTS / DELETE POST", () => {
  it("should delete own post", async () => {
    const user = await User.create({
      username: "deleter",
      email: "del@mail.com",
      password: "hashed",
    });

    const post = await Post.create({
      user: user._id,
      caption: "to delete",
      media: [],
    });

    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET);

    const res = await request(app)
      .delete(`/posts/${post._id}`)
      .set("Authorization", `Bearer ${token}`);

    expect(res.statusCode).toBe(200);
  });
});
