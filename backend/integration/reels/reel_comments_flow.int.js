import request from "supertest";
import app from "../../src/app.js";
import {
  connectTestDB,
  clearTestDB,
  disconnectTestDB,
} from "../setup/test_database.js";

describe("REELS / COMMENTS FLOW", () => {
  let token, reelId;

  beforeAll(async () => {
    await connectTestDB();

    await request(app).post("/auth/register").send({
      username: "reel_comment_user",
      email: "reel_comment@test.com",
      password: "Password123!",
    });

    const login = await request(app).post("/auth/login").send({
      email: "reel_comment@test.com",
      password: "Password123!",
    });

    token = login.body.accessToken;

    const reel = await request(app)
      .post("/reels")
      .set("Authorization", `Bearer ${token}`)
      .send({
        mediaUrl: "https://cdn.test/reel_comment.mp4",
        caption: "comment reel",
      });

    reelId = reel.body._id;
  });

  afterAll(async () => {
    await clearTestDB();
    await disconnectTestDB();
  });

  it("should add comment to reel", async () => {
    const res = await request(app)
      .post(`/reels/${reelId}/comments`)
      .set("Authorization", `Bearer ${token}`)
      .send({ text: "Nice reel!" });

    expect(res.statusCode).toBe(200);
    expect(res.body.text).toBe("Nice reel!");
  });

  it("should fetch reel comments", async () => {
    const res = await request(app)
      .get(`/reels/${reelId}/comments`)
      .set("Authorization", `Bearer ${token}`);

    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBeGreaterThanOrEqual(1);
  });
});
