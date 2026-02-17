import request from "supertest";
import app from "../../src/app.js";
import { connectTestDB, clearTestDB, disconnectTestDB } from "../setup/test_database.js";

describe("AUTH / PASSWORD RESET", () => {
  beforeAll(async () => {
    await connectTestDB();

    await request(app).post("/auth/register").send({
      username: "reset_user",
      email: "reset@test.com",
      password: "Password123!",
    });
  });

  afterAll(async () => {
    await clearTestDB();
    await disconnectTestDB();
  });

  it("should request password reset", async () => {
    const res = await request(app)
      .post("/auth/password/forgot")
      .send({ email: "reset@test.com" });

    expect(res.statusCode).toBe(200);
  });

  it("should reject reset for unknown email", async () => {
    const res = await request(app)
      .post("/auth/password/forgot")
      .send({ email: "unknown@test.com" });

    expect(res.statusCode).toBe(404);
  });
});
