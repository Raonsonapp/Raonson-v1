import request from "supertest";
import app from "../../src/app.js";
import { Story } from "../../src/models/story.model.js";
import {
  connectTestDB,
  clearTestDB,
  disconnectTestDB,
} from "../setup/test_database.js";

describe("STORIES / EXPIRY FLOW", () => {
  let token;

  beforeAll(async () => {
    await connectTestDB();

    await request(app).post("/auth/register").send({
      username: "story_expire",
      email: "story_expire@test.com",
      password: "Password123!",
    });

    const login = await request(app).post("/auth/login").send({
      email: "story_expire@test.com",
      password: "Password123!",
    });

    token = login.body.accessToken;

    await Story.create({
      user: login.body.user.id,
      mediaUrl: "https://cdn.test/expired.jpg",
      mediaType: "image",
      createdAt: new Date(Date.now() - 25 * 60 * 60 * 1000),
    });
  });

  afterAll(async () => {
    await clearTestDB();
    await disconnectTestDB();
  });

  it("should not return expired stories", async () => {
    const res = await request(app)
      .get("/stories")
      .set("Authorization", `Bearer ${token}`);

    expect(res.statusCode).toBe(200);
    expect(res.body).toEqual({});
  });
});
