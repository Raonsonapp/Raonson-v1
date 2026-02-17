import request from "supertest";
import app from "../../src/app.js";
import { connectTestDB, clearTestDB, disconnectTestDB } from "../setup/test_database.js";

describe("AUTH / LOGIN FLOW", () => {
  beforeAll(async () => {
    await connectTestDB();
  });

  afterAll(async () => {
    await clearTestDB();
    await disconnectTestDB();
  });

  it("should login user with valid credentials", async () => {
    await request(app).post("/auth/register").send({
      username: "login_user",
      email: "login@test.com",
      password: "Password123!",
    });

    const res = await request(app).post("/auth/login").send({
      email: "login@test.com",
      password: "Password123!",
    });

    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty("accessToken");
    expect(res.body).toHaveProperty("refreshToken");
  });

  it("should reject invalid password", async () => {
    const res = await request(app).post("/auth/login").send({
      email: "login@test.com",
      password: "WrongPass",
    });

    expect(res.statusCode).toBe(401);
  });
});
