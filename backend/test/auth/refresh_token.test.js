import request from "supertest";
import app from "../../src/app.js";
import { User } from "../../src/models/user.model.js";
import jwt from "jsonwebtoken";

describe("AUTH / REFRESH TOKEN", () => {
  it("should issue new access token", async () => {
    const user = await User.create({
      username: "refresh",
      email: "refresh@mail.com",
      password: "hashed",
      emailVerified: true,
    });

    const refreshToken = jwt.sign(
      { id: user._id },
      process.env.JWT_SECRET,
      { expiresIn: "30d" }
    );

    const res = await request(app)
      .post("/auth/refresh-token")
      .send({ refreshToken });

    expect(res.statusCode).toBe(200);
    expect(res.body.accessToken).toBeDefined();
  });
});
