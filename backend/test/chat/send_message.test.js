import request from "supertest";
import app from "../../src/app.js";
import { User } from "../../src/models/user.model.js";
import { Message } from "../../src/models/message.model.js";
import jwt from "jsonwebtoken";

describe("CHAT / SEND MESSAGE", () => {
  it("should send text message", async () => {
    const user = await User.create({ username: "sender", email: "s@mail.com", password: "x" });
    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET);

    const res = await request(app)
      .post("/chat/message")
      .set("Authorization", `Bearer ${token}`)
      .send({
        roomId: "room_test",
        text: "hello",
      });

    expect(res.statusCode).toBe(200);
    expect(res.body.text).toBe("hello");
  });
});
