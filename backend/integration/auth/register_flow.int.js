import request from "supertest";
import app from "../../src/app.js";
import { connectTestDB, clearTestDB, disconnectTestDB } from "../setup/test_database.js";

describe("AUTH / REGISTER FLOW", () => {
  beforeAll(async () => {
    await connectTestDB();
  });

  afterAll(async () => {
    await clearTestDB();
    await disconnectTestDB();
  });

  it("should register new user", async () => {
    const res = await request(app).post("/auth/register").send({
      username: "new_user",
      email: "new@test.com",
      password: "Password123!",
    });

    expect(res.statusCode).toBe(201);
    expect(res.body).toHaveProperty("user");
    expect(res.body.user.username).toBe("new_user");
  });

  it("should reject duplicate email", async () => {
    const res = await request(app).post("/auth/register").send({
      username: "dup_user",
      email: "new@test.com",
      password: "Password123!",
    });

    expect(res.statusCode).toBe(409);
  });
});
