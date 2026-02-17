import request from "supertest";
import app from "../../src/app.js";
import { User } from "../../src/models/user.model.js";

describe("AUTH / VERIFY EMAIL", () => {
  it("should verify email by token", async () => {
    const user = await User.create({
      username: "verify",
      email: "verify@mail.com",
      password: "hashed",
      emailVerifyToken: "testtoken",
      emailVerified: false,
    });

    const res = await request(app).get(
      `/auth/verify-email?token=testtoken`
    );

    expect(res.statusCode).toBe(200);

    const updated = await User.findById(user._id);
    expect(updated.emailVerified).toBe(true);
  });
});
