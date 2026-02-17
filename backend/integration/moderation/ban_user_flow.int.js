import request from "supertest";
import app from "../../src/app.js";
import {
  connectTestDB,
  clearTestDB,
  disconnectTestDB,
} from "../setup/test_database.js";

describe("MODERATION / BAN USER FLOW", () => {
  let adminToken, userToken, userId;

  beforeAll(async () => {
    await connectTestDB();

    // Admin
    await request(app).post("/auth/register").send({
      username: "admin_user",
      email: "admin@test.com",
      password: "AdminPass123!",
      role: "admin",
    });

    const adminLogin = await request(app).post("/auth/login").send({
      email: "admin@test.com",
      password: "AdminPass123!",
    });

    adminToken = adminLogin.body.accessToken;

    // Normal user
    await request(app).post("/auth/register").send({
      username: "banned_user",
      email: "banned@test.com",
      password: "Password123!",
    });

    const userLogin = await request(app).post("/auth/login").send({
      email: "banned@test.com",
      password: "Password123!",
    });

    userToken = userLogin.body.accessToken;
    userId = userLogin.body.user._id;
  });

  afterAll(async () => {
    await clearTestDB();
    await disconnectTestDB();
  });

  it("should ban user and block access", async () => {
    const ban = await request(app)
      .post(`/admin/users/${userId}/ban`)
      .set("Authorization", `Bearer ${adminToken}`)
      .send({ reason: "violation" });

    expect(ban.statusCode).toBe(200);
    expect(ban.body.banned).toBe(true);

    const blockedAction = await request(app)
      .post("/posts")
      .set("Authorization", `Bearer ${userToken}`)
      .send({
        caption: "Should not work",
        media: [],
      });

    expect(blockedAction.statusCode).toBe(403);
  });
});
