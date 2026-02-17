import request from "supertest";
import app from "../../src/app.js";
import { User } from "../../src/models/user.model.js";
import jwt from "jsonwebtoken";

describe("STORIES / CREATE", () => {
  it("should create a new story", async () => {
    const user = await User.create({
      username: "storyuser",
      email: "story@mail.com",
      password: "hashed",
    });

    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET);

    const res = await request(app)
      .post("/stories")
      .set("Authorization", `Bearer ${token}`)
      .send({
        mediaUrl: "https://cdn.test/story.jpg",
        mediaType: "image",
      });

    expect(res.statusCode).toBe(200);
    expect(res.body.mediaUrl).toBeDefined();
    expect(res.body.user.toString()).toBe(user._id.toString());
  });
});
