import request from "supertest";
import app from "../../src/app.js";
import { connectTestDB, clearTestDB, disconnectTestDB } from "../setup/test_database.js";

describe("USERS / FOLLOW & UNFOLLOW", () => {
  let tokenA, tokenB, userBId;

  beforeAll(async () => {
    await connectTestDB();

    await request(app).post("/auth/register").send({
      username: "user_a",
      email: "a@test.com",
      password: "Password123!",
    });

    await request(app).post("/auth/register").send({
      username: "user_b",
      email: "b@test.com",
      password: "Password123!",
    });

    const loginA = await request(app).post("/auth/login").send({
      email: "a@test.com",
      password: "Password123!",
    });

    const loginB = await request(app).post("/auth/login").send({
      email: "b@test.com",
      password: "Password123!",
    });

    tokenA = loginA.body.accessToken;
    tokenB = loginB.body.accessToken;

    const profileB = await request(app)
      .get("/profile/me")
      .set("Authorization", `Bearer ${tokenB}`);

    userBId = profileB.body._id;
  });

  afterAll(async () => {
    await clearTestDB();
    await disconnectTestDB();
  });

  it("should follow user", async () => {
    const res = await request(app)
      .post(`/follow/${userBId}`)
      .set("Authorization", `Bearer ${tokenA}`);

    expect(res.statusCode).toBe(200);
    expect(res.body.following).toBe(true);
  });

  it("should unfollow user", async () => {
    const res = await request(app)
      .post(`/follow/${userBId}`)
      .set("Authorization", `Bearer ${tokenA}`);

    expect(res.statusCode).toBe(200);
    expect(res.body.following).toBe(false);
  });
});
