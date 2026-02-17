import request from "supertest";
import app from "../../src/app.js";
import { connectTestDB, clearTestDB, disconnectTestDB } from "../setup/test_database.js";

describe("USERS / PRIVACY FLOW", () => {
  let token;

  beforeAll(async () => {
    await connectTestDB();

    await request(app).post("/auth/register").send({
      username: "private_user",
      email: "private@test.com",
      password: "Password123!",
    });

    const login = await request(app).post("/auth/login").send({
      email: "private@test.com",
      password: "Password123!",
    });

    token = login.body.accessToken;
  });

  afterAll(async () => {
    await clearTestDB();
    await disconnectTestDB();
  });

  it("should set account to private", async () => {
    const res = await request(app)
      .put("/profile/privacy")
      .set("Authorization", `Bearer ${token}`)
      .send({ isPrivate: true });

    expect(res.statusCode).toBe(200);
    expect(res.body.isPrivate).toBe(true);
  });
});
