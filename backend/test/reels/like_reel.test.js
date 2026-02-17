import request from "supertest";
import app from "../../src/app.js";
import { User } from "../../src/models/user.model.js";
import { Reel } from "../../src/models/reel.model.js";
import jwt from "jsonwebtoken";

describe("REELS / LIKE", () => {
  it("should toggle like on reel", async () => {
    const user = await User.create({
      username: "liker",
      email: "like@mail.com",
      password: "hashed",
    });

    const reel = await Reel.create({
      user: user._id,
      videoUrl: "https://cdn.test/reel.mp4",
    });

    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET);

    const res = await request(app)
      .post(`/reels/${reel._id}/like`)
      .set("Authorization", `Bearer ${token}`);

    expect(res.statusCode).toBe(200);
    expect(res.body.liked).toBe(true);
  });
});
