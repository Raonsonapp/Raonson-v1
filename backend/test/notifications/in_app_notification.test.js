import request from "supertest";
import app from "../../src/app.js";
import { User } from "../../src/models/user.model.js";
import { Notification } from "../../src/models/notification.model.js";
import jwt from "jsonwebtoken";

describe("NOTIFICATIONS / IN-APP", () => {
  it("should fetch in-app notifications for user", async () => {
    const user = await User.create({
      username: "notify_user",
      email: "notify@mail.com",
      password: "x",
    });

    await Notification.create({
      to: user._id,
      from: user._id,
      type: "follow",
      targetId: user._id,
    });

    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET);

    const res = await request(app)
      .get("/notifications")
      .set("Authorization", `Bearer ${token}`);

    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBeGreaterThan(0);
  });

  it("should mark notification as read", async () => {
    const user = await User.create({
      username: "reader_notify",
      email: "read@mail.com",
      password: "x",
    });

    const notif = await Notification.create({
      to: user._id,
      from: user._id,
      type: "comment",
      targetId: "post_id",
    });

    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET);

    const res = await request(app)
      .post("/notifications/read")
      .set("Authorization", `Bearer ${token}`)
      .send({ id: notif._id });

    expect(res.statusCode).toBe(200);

    const updated = await Notification.findById(notif._id);
    expect(updated.read).toBe(true);
  });
});
