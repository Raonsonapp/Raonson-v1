import request from "supertest";
import app from "../../src/app.js";
import {
  connectTestDB,
  clearTestDB,
  disconnectTestDB,
} from "../setup/test_database.js";

describe("STORIES / CREATE FLOW", () => {
  let token;

  beforeAll(async () => {
    await connectTestDB();

    await request(app).post("/auth/register").send({
      username: "story_creator",
      email: "story_creator@test.com",
      password: "Password123!",
    });

    const login = await request(app).post("/auth/login").send({
      email: "story_creator@test.com",
      password: "Password123!",
    });

    token = login.body.accessToken;
  });

  afterAll(async () => {
    await clearTestDB();
    await disconnectTestDB();
  });

  it("should create a new story", async () => {
    const res = await request(app)
      .post("/stories")
      .set("Authorization", `Bearer ${token}`)
      .send({
        mediaUrl: "https://cdn.test/story1.jpg",
        mediaType: "image",
      });

    expect(res.statusCode).toBe(200);
    expect(res.body.mediaUrl).toContain("story1");
    expect(res.body.mediaType).toBe("image");
  });
});
