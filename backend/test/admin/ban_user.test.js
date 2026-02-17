import request from "supertest";
import app from "../../src/app.js";
import { User } from "../../src/models/user.model.js";
import jwt from "jsonwebtoken";

describe("ADMIN / BAN USER", () => {
  it("admin should ban a user", async () => {
    const admin = await User.create({
      username: "admin",
      email: "admin@mail.com",
      password: "x",
      role: "admin",
    });

    const user = await User.create({
      username: "bad_user",
      email: "bad@mail.com",
      password: "x",
    });

    const token = jwt.sign(
      { id: admin._id, role: "admin" },
      process.env.JWT_SECRET
    );

    const res = await request(app)
      .post("/admin/ban")
      .set("Authorization", `Bearer ${token}`)
      .send({ userId: user._id });

    expect(res.statusCode).toBe(200);

    const updated = await User.findById(user._id);
    expect(updated.banned).toBe(true);
  });
});
