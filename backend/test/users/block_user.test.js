import request from "supertest";
import app from "../../src/app.js";
import { User } from "../../src/models/user.model.js";
import jwt from "jsonwebtoken";

describe("USERS / BLOCK USER", () => {
  it("should block another user", async () => {
    const userA = await User.create({
      username: "blocker",
      email: "blocker@mail.com",
      password: "hashed",
    });

    const userB = await User.create({
      username: "blocked",
      email: "blocked@mail.com",
      password: "hashed",
    });

    const token = jwt.sign(
      { id: userA._id },
      process.env.JWT_SECRET
    );

    const res = await request(app)
      .post(`/users/${userB._id}/block`)
      .set("Authorization", `Bearer ${token}`);

    expect(res.statusCode).toBe(200);
    expect(res.body.blocked).toBe(true);
  });
});
