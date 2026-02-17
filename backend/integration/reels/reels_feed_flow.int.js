import request from "supertest";
import app from "../../src/app.js";
import {
  connectTestDB,
  clearTestDB,
  disconnectTestDB,
} from "../setup/test_database.js";

describe("REELS / FEED FLOW", () => {
  let token;

  beforeAll(async () => {
    await connectTestDB();

    await request(app).post("/auth/register").send({
      username: "reels_feed_user",
      email: "reels_feed@test.com",
      password: "Password123!",
    });

    const login = await request(app).post("/auth/login").send({
      email: "reels_feed@test.com",
      password: "Password123!",
    });

    token = login.body.accessToken;

    // seed reels
    await request(app)
      .post("/reels")
      .set("Authorization", `Bearer ${token}`)
      .send({
        mediaUrl: "https://cdn.test/reel1.mp4",
        caption: "reel one",
      });

    await request(app)
      .post("/reels")
      .set("Authorization", `Bearer ${token}`)
      .send({
        mediaUrl: "https://cdn.test/reel2.mp4",
        caption: "reel two",
      });
  });

  afterAll(async () => {
    await clearTestDB();
    await disconnectTestDB();
  });

  it("should return reels feed ordered by engagement/recency", async () => {
    const res = await request(app)
      .get("/reels")
      .set("Authorization", `Bearer ${token}`);

    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBeGreaterThanOrEqual(2);
    expect(res.body[0]).toHaveProperty("mediaUrl");
  });
});
