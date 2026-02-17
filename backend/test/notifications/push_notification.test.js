import request from "supertest";
import app from "../../src/app.js";
import { User } from "../../src/models/user.model.js";
import { Notification } from "../../src/models/notification.model.js";
import jwt from "jsonwebtoken";

describe("NOTIFICATIONS / PUSH", () => {
  it("should create push notification on like", async () => {
    const from = await User.create({
      username: "liker",
      email: "liker@mail.com",
      password: "x",
    });

    const to = await User.create({
      username: "owner",
      email: "owner@mail.com",
      password: "x",
    });

    const token = jwt.sign({ id: from._id }, process.env.JWT_SECRET);

    const res = await request(app)
      .post("/notifications/push")
      .set("Authorization", `Bearer ${token}`)
      .send({
        to: to._id,
        type: "like",
        targetId: "post_test_id",
      });

    expect(res.statusCode).toBe(200);

    const notif = await Notification.findOne({
      to: to._id,
      type: "like",
    });

    expect(notif).not.toBeNull();
    expect(notif.read).toBe(false);
  });
});
