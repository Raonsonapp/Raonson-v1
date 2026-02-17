import request from "supertest";
import app from "../../src/app.js";
import { User } from "../../src/models/user.model.js";
import jwt from "jsonwebtoken";

describe("USERS / FOLLOW USER", () => {
  it("should follow another user", async () => {
    const userA = await User.create({
      username: "userA",
      email: "a@mail.com",
      password: "hashed",
    });

    const userB = await User.create({
      username: "userB",
      email: "b@mail.com",
      password: "hashed",
    });

    const token = jwt.sign(
      { id: userA._id },
      process.env.JWT_SECRET
    );

    const res = await request(app)
      .post(`/follow/${userB._id}`)
      .set("Authorization", `Bearer ${token}`);

    expect(res.statusCode).toBe(200);

    const updatedA = await User.findById(userA._id);
    expect(updatedA.following.length).toBe(1);
  });
});
