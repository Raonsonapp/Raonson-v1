import request from "supertest";
import app from "../../src/app.js";
import { connectTestDB, clearTestDB, disconnectTestDB } from "../setup/test_database.js";

describe("AUTH / TOKEN REFRESH", () => {
  let refreshToken;

  beforeAll(async () => {
    await connectTestDB();

    await request(app).post("/auth/register").send({
      username: "refresh_user",
      email: "refresh@test.com",
      password: "Password123!",
    });

    const login = await request(app).post("/auth/login").send({
      email: "refresh@test.com",
      password: "Password123!",
    });

    refreshToken = login.body.refreshToken;
  });

  afterAll(async () => {
    await clearTestDB();
    await disconnectTestDB();
  });

  it("should issue new access token", async () => {
    const res = await request(app)
      .post("/auth/refresh")
      .send({ refreshToken });

    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty("accessToken");
  });
});
