import request from "supertest";
import app from "../../src/app.js";
import {
  connectTestDB,
  clearTestDB,
  disconnectTestDB,
} from "../setup/test_database.js";

describe("REELS / INTERACTION FLOW", () => {
  let token, reelId;

  beforeAll(async () => {
    await connectTestDB();

    await request(app).post("/auth/register").send({
      username: "reel_interact_user",
      email: "reel_interact@test.com",
      password: "Password123!",
    });

    const login = await request(app).post("/auth/login").send({
      email: "reel_interact@test.com",
      password: "Password123!",
    });

    token = login.body.accessToken;

    const reel = await request(app)
      .post("/reels")
      .set("Authorization", `Bearer ${token}`)
      .send({
        mediaUrl: "https://cdn.test/reel_interact.mp4",
        caption: "interact reel",
      });

    reelId = reel.body._id;
  });

  afterAll(async () => {
    await clearTestDB();
    await disconnectTestDB();
  });

  it("should add view to reel", async () => {
    const res = await request(app)
      .post(`/reels/${reelId}/view`)
      .set("Authorization", `Bearer ${token}`);

    expect(res.statusCode).toBe(200);
    expect(res.body.views).toBeGreaterThanOrEqual(1);
  });

  it("should like and unlike reel", async () => {
    const like = await request(app)
      .post(`/reels/${reelId}/like`)
      .set("Authorization", `Bearer ${token}`);

    expect(like.statusCode).toBe(200);
    expect(like.body.liked).toBe(true);

    const unlike = await request(app)
      .post(`/reels/${reelId}/like`)
      .set("Authorization", `Bearer ${token}`);

    expect(unlike.statusCode).toBe(200);
    expect(unlike.body.liked).toBe(false);
  });

  it("should save and unsave reel", async () => {
    const save = await request(app)
      .post(`/reels/${reelId}/save`)
      .set("Authorization", `Bearer ${token}`);

    expect(save.statusCode).toBe(200);
    expect(save.body.saved).toBe(true);

    const unsave = await request(app)
      .post(`/reels/${reelId}/save`)
      .set("Authorization", `Bearer ${token}`);

    expect(unsave.statusCode).toBe(200);
    expect(unsave.body.saved).toBe(false);
  });
});
