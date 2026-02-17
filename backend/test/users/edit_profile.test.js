import request from "supertest";
import app from "../../src/app.js";
import { User } from "../../src/models/user.model.js";
import jwt from "jsonwebtoken";

describe("USERS / EDIT PROFILE", () => {
  it("should update profile data", async () => {
    const user = await User.create({
      username: "edituser",
      email: "edit@mail.com",
      password: "hashed",
    });

    const token = jwt.sign(
      { id: user._id },
      process.env.JWT_SECRET
    );

    const res = await request(app)
      .put("/profile")
      .set("Authorization", `Bearer ${token}`)
      .send({
        username: "editeduser",
        bio: "New bio",
      });

    expect(res.statusCode).toBe(200);
    expect(res.body.username).toBe("editeduser");
  });
});
