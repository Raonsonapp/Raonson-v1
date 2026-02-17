import request from "supertest";
import app from "../../src/app.js";
import { User } from "../../src/models/user.model.js";

describe("AUTH / REGISTER", () => {
  it("should register new user", async () => {
    const res = await request(app).post("/auth/register").send({
      username: "testuser",
      email: "test@mail.com",
      password: "password123",
    });

    expect(res.statusCode).toBe(201);
    expect(res.body.user.username).toBe("testuser");

    const user = await User.findOne({ email: "test@mail.com" });
    expect(user).not.toBeNull();
  });

  it("should not register duplicate email", async () => {
    await User.create({
      username: "x",
      email: "dup@mail.com",
      password: "hashed",
    });

    const res = await request(app).post("/auth/register").send({
      username: "y",
      email: "dup@mail.com",
      password: "123456",
    });

    expect(res.statusCode).toBe(409);
  });
});
