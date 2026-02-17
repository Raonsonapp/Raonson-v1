import request from "supertest";
import app from "../../src/app.js";
import { User } from "../../src/models/user.model.js";
import jwt from "jsonwebtoken";

describe("CHAT / CREATE ROOM", () => {
  it("should create private chat room", async () => {
    const u1 = await User.create({ username: "u1", email: "u1@mail.com", password: "x" });
    const u2 = await User.create({ username: "u2", email: "u2@mail.com", password: "x" });

    const token = jwt.sign({ id: u1._id }, process.env.JWT_SECRET);

    const res = await request(app)
      .post("/chat/room")
      .set("Authorization", `Bearer ${token}`)
      .send({ userId: u2._id });

    expect(res.statusCode).toBe(200);
    expect(res.body.participants.length).toBe(2);
  });
});
