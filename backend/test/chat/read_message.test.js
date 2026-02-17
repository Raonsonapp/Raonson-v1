import request from "supertest";
import app from "../../src/app.js";
import { User } from "../../src/models/user.model.js";
import jwt from "jsonwebtoken";

describe("CHAT / READ MESSAGE", () => {
  it("should mark message as read", async () => {
    const user = await User.create({ username: "reader", email: "r@mail.com", password: "x" });
    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET);

    const res = await request(app)
      .post("/chat/read")
      .set("Authorization", `Bearer ${token}`)
      .send({ messageId: "msg_test" });

    expect(res.statusCode).toBe(200);
    expect(res.body.read).toBe(true);
  });
});
