import request from "supertest";
import app from "../../src/app.js";
import { connectTestDB, clearTestDB, disconnectTestDB } from "../setup/test_database.js";

describe("USERS / PROFILE FLOW", () => {
  let token;

  beforeAll(async () => {
    await connectTestDB();

    await request(app).post("/auth/register").send({
      username: "profile_user",
      email: "profile@test.com",
      password: "Password123!",
    });

    const login = await request(app).post("/auth/login").send({
      email: "profile@test.com",
      password: "Password123!",
    });

    token = login.body.accessToken;
  });

  afterAll(async () => {
    await clearTestDB();
    await disconnectTestDB();
  });

  it("should get own profile", async () => {
    const res = await request(app)
      .get("/profile/me")
      .set("Authorization", `Bearer ${token}`);

    expect(res.statusCode).toBe(200);
    expect(res.body.username).toBe("profile_user");
  });

  it("should update profile bio", async () => {
    const res = await request(app)
      .put("/profile/me")
      .set("Authorization", `Bearer ${token}`)
      .send({ bio: "Hello world" });

    expect(res.statusCode).toBe(200);
    expect(res.body.bio).toBe("Hello world");
  });
});
