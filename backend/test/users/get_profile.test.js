import request from "supertest";
import app from "../../src/app.js";
import { User } from "../../src/models/user.model.js";

describe("USERS / GET PROFILE", () => {
  it("should return public user profile", async () => {
    const user = await User.create({
      username: "profileuser",
      email: "profile@mail.com",
      password: "hashed",
      isPrivate: false,
    });

    const res = await request(app).get(`/users/${user._id}`);

    expect(res.statusCode).toBe(200);
    expect(res.body.username).toBe("profileuser");
  });

  it("should hide private profile data", async () => {
    const user = await User.create({
      username: "privateuser",
      email: "private@mail.com",
      password: "hashed",
      isPrivate: true,
    });

    const res = await request(app).get(`/users/${user._id}`);

    expect(res.statusCode).toBe(200);
    expect(res.body.isPrivate).toBe(true);
  });
});
