import request from "supertest";
import app from "../../src/app.js";
import { User } from "../../src/models/user.model.js";
import jwt from "jsonwebtoken";

describe("REELS / CREATE", () => {
  it("should create a reel", async () => {
    const user = await User.create({
      username: "reeluser",
      email: "reel@mail.com",
      password: "hashed",
    });

    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET);

    const res = await request(app)
      .post("/reels")
      .set("Authorization", `Bearer ${token}`)
      .send({
        videoUrl: "https://cdn.test/reel.mp4",
        caption: "my first reel",
      });

    expect(res.statusCode).toBe(200);
    expect(res.body.videoUrl).toBeDefined();
    expect(res.body.user.toString()).toBe(user._id.toString());
  });
});
