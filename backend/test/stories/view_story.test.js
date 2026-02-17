import request from "supertest";
import app from "../../src/app.js";
import { User } from "../../src/models/user.model.js";
import { Story } from "../../src/models/story.model.js";
import jwt from "jsonwebtoken";

describe("STORIES / VIEW", () => {
  it("should count story view only once per user", async () => {
    const user = await User.create({
      username: "viewer",
      email: "viewer@mail.com",
      password: "hashed",
    });

    const story = await Story.create({
      user: user._id,
      mediaUrl: "https://cdn.test/story.jpg",
      mediaType: "image",
    });

    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET);

    await request(app)
      .post(`/stories/${story._id}/view`)
      .set("Authorization", `Bearer ${token}`);

    const res = await request(app)
      .post(`/stories/${story._id}/view`)
      .set("Authorization", `Bearer ${token}`);

    expect(res.statusCode).toBe(200);
    expect(res.body.views).toBe(1);
  });
});
