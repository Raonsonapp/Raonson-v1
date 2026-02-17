import request from "supertest";
import app from "../../src/app.js";
import {
  connectTestDB,
  clearTestDB,
  disconnectTestDB,
} from "../setup/test_database.js";

describe("FEED / HOME FEED FLOW", () => {
  let token;

  beforeAll(async () => {
    await connectTestDB();

    await request(app).post("/auth/register").send({
      username: "feed_user",
      email: "feed@test.com",
      password: "Password123!",
    });

    const login = await request(app).post("/auth/login").send({
      email: "feed@test.com",
      password: "Password123!",
    });

    token = login.body.accessToken;

    // create posts
    for (let i = 0; i < 5; i++) {
      await request(app)
        .post("/posts")
        .set("Authorization", `Bearer ${token}`)
        .send({
          caption: `Post ${i}`,
          media: [{ url: `https://cdn.test/${i}.jpg`, type: "image" }],
        });
    }
  });

  afterAll(async () => {
    await clearTestDB();
    await disconnectTestDB();
  });

  it("should return home feed", async () => {
    const res = await request(app)
      .get("/feed")
      .set("Authorization", `Bearer ${token}`);

    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBeGreaterThan(0);
  });
});
