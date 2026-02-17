import request from "supertest";
import app from "../../src/app.js";
import { User } from "../../src/models/user.model.js";
import jwt from "jsonwebtoken";

describe("POSTS / CREATE POST", () => {
  it("should create a new post", async () => {
    const user = await User.create({
      username: "postcreator",
      email: "post@mail.com",
      password: "hashed",
    });

    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET);

    const res = await request(app)
      .post("/posts")
      .set("Authorization", `Bearer ${token}`)
      .send({
        caption: "Hello world",
        media: [{ url: "https://img.com/1.jpg", type: "image" }],
      });

    expect(res.statusCode).toBe(200);
    expect(res.body.caption).toBe("Hello world");
  });
});
