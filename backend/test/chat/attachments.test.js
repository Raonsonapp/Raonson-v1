import request from "supertest";
import app from "../../src/app.js";
import { User } from "../../src/models/user.model.js";
import jwt from "jsonwebtoken";

describe("CHAT / ATTACHMENTS", () => {
  it("should send media attachment", async () => {
    const user = await User.create({ username: "media", email: "m@mail.com", password: "x" });
    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET);

    const res = await request(app)
      .post("/chat/message")
      .set("Authorization", `Bearer ${token}`)
      .send({
        roomId: "room_media",
        mediaUrl: "https://cdn.test/file.jpg",
        mediaType: "image",
      });

    expect(res.statusCode).toBe(200);
    expect(res.body.mediaUrl).toBeDefined();
  });
});
