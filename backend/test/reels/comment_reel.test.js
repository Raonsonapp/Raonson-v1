import request from "supertest";
import app from "../../src/app.js";
import { User } from "../../src/models/user.model.js";
import { Reel } from "../../src/models/reel.model.js";
import jwt from "jsonwebtoken";

describe("REELS / COMMENT", () => {
  it("should add comment to reel", async () => {
    const user = await User.create({
      username: "commenter",
      email: "comment@mail.com",
      password: "hashed",
    });

    const reel = await Reel.create({
      user: user._id,
      videoUrl: "https://cdn.test/reel.mp4",
    });

    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET);

    const res = await request(app)
      .post(`/comments/reel/${reel._id}`)
      .set("Authorization", `Bearer ${token}`)
      .send({ text: "🔥🔥🔥" });

    expect(res.statusCode).toBe(200);
    expect(res.body.text).toBe("🔥🔥🔥");
  });
});
