import request from "supertest";
import app from "../../src/app.js";
import { User } from "../../src/models/user.model.js";
import bcrypt from "bcryptjs";

describe("AUTH / LOGIN", () => {
  beforeEach(async () => {
    const hash = await bcrypt.hash("password123", 10);
    await User.create({
      username: "loginuser",
      email: "login@mail.com",
      password: hash,
      emailVerified: true,
    });
  });

  it("should login with correct credentials", async () => {
    const res = await request(app).post("/auth/login").send({
      email: "login@mail.com",
      password: "password123",
    });

    expect(res.statusCode).toBe(200);
    expect(res.body.accessToken).toBeDefined();
  });

  it("should reject invalid password", async () => {
    const res = await request(app).post("/auth/login").send({
      email: "login@mail.com",
      password: "wrong",
    });

    expect(res.statusCode).toBe(401);
  });
});
