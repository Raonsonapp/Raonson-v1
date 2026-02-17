import request from "supertest";
import app from "../../src/app.js";
import { User } from "../../src/models/user.model.js";
import jwt from "jsonwebtoken";

describe("ADMIN / ANALYTICS", () => {
  it("admin should get platform analytics", async () => {
    const admin = await User.create({
      username: "admin2",
      email: "admin2@mail.com",
      password: "x",
      role: "admin",
    });

    const token = jwt.sign(
      { id: admin._id, role: "admin" },
      process.env.JWT_SECRET
    );

    const res = await request(app)
      .get("/admin/analytics")
      .set("Authorization", `Bearer ${token}`);

    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty("users");
    expect(res.body).toHaveProperty("posts");
    expect(res.body).toHaveProperty("stories");
    expect(res.body).toHaveProperty("reels");
  });
});
