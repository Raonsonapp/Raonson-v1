import request from "supertest";
import app from "../../src/app.js";
import {
  connectTestDB,
  clearTestDB,
  disconnectTestDB,
} from "../setup/test_database.js";

describe("NOTIFICATIONS / READ FLOW", () => {
  let token, notificationId;

  beforeAll(async () => {
    await connectTestDB();

    await request(app).post("/auth/register").send({
      username: "read_notify_user",
      email: "readnotify@test.com",
      password: "Password123!",
    });

    const login = await request(app).post("/auth/login").send({
      email: "readnotify@test.com",
      password: "Password123!",
    });

    token = login.body.accessToken;

    // Self-follow trigger (system notification)
    await request(app)
      .post(`/notifications/system`)
      .set("Authorization", `Bearer ${token}`)
      .send({
        type: "system",
        message: "Welcome to Raonson",
      });

    const list = await request(app)
      .get("/notifications")
      .set("Authorization", `Bearer ${token}`);

    notificationId = list.body[0]._id;
  });

  afterAll(async () => {
    await clearTestDB();
    await disconnectTestDB();
  });

  it("should mark notification as read", async () => {
    const res = await request(app)
      .post(`/notifications/${notificationId}/read`)
      .set("Authorization", `Bearer ${token}`);

    expect(res.statusCode).toBe(200);
    expect(res.body.read).toBe(true);
  });
});
