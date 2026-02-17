import request from "supertest";
import app from "../../src/app.js";
import { connectTestDB, clearTestDB, disconnectTestDB } from "../setup/test_database.js";

describe("USERS / BLOCK USER", () => {
  let tokenA, userBId;

  beforeAll(async () => {
    await connectTestDB();

    await request(app).post("/auth/register").send({
      username: "blocker",
      email: "blocker@test.com",
      password: "Password123!",
    });

    await request(app).post("/auth/register").send({
      username: "blocked",
      email: "blocked@test.com",
      password: "Password123!",
    });

    const loginA = await request(app).post("/auth/login").send({
      email: "blocker@test.com",
      password: "Password123!",
    });

    tokenA = loginA.body.accessToken;

    const profileB = await request(app)
      .post("/auth/login")
      .send({ email: "blocked@test.com", password: "Password123!" });

    const profile = await request(app)
      .get("/profile/me")
      .set("Authorization", `Bearer ${profileB.body.accessToken}`);

    userBId = profile.body._id;
  });

  afterAll(async () => {
    await clearTestDB();
    await disconnectTestDB();
  });

  it("should block user", async () => {
    const res = await request(app)
      .post(`/users/${userBId}/block`)
      .set("Authorization", `Bearer ${tokenA}`);

    expect(res.statusCode).toBe(200);
    expect(res.body.blocked).toBe(true);
  });
});
