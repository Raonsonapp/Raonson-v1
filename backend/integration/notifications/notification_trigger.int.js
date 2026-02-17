import request from "supertest";
import app from "../../src/app.js";
import {
  connectTestDB,
  clearTestDB,
  disconnectTestDB,
} from "../setup/test_database.js";

describe("NOTIFICATIONS / TRIGGER FLOW", () => {
  let tokenA, tokenB, userBId;

  beforeAll(async () => {
    await connectTestDB();

    // User A
    await request(app).post("/auth/register").send({
      username: "notify_user_a",
      email: "notifyA@test.com",
      password: "Password123!",
    });

    const loginA = await request(app).post("/auth/login").send({
      email: "notifyA@test.com",
      password: "Password123!",
    });

    tokenA = loginA.body.accessToken;

    // User B
    await request(app).post("/auth/register").send({
      username: "notify_user_b",
      email: "notifyB@test.com",
      password: "Password123!",
    });

    const loginB = await request(app).post("/auth/login").send({
      email: "notifyB@test.com",
      password: "Password123!",
    });

    tokenB = loginB.body.accessToken;
    userBId = loginB.body.user._id;
  });

  afterAll(async () => {
    await clearTestDB();
    await disconnectTestDB();
  });

  it("should trigger notification on follow", async () => {
    const res = await request(app)
      .post(`/follow/${userBId}`)
      .set("Authorization", `Bearer ${tokenA}`);

    expect(res.statusCode).toBe(200);

    const notifications = await request(app)
      .get("/notifications")
      .set("Authorization", `Bearer ${tokenB}`);

    expect(notifications.statusCode).toBe(200);
    expect(notifications.body.length).toBeGreaterThan(0);

    const followNotification = notifications.body.find(
      (n) => n.type === "follow"
    );

    expect(followNotification).toBeDefined();
    expect(followNotification.actor.username).toBe("notify_user_a");
  });
});
