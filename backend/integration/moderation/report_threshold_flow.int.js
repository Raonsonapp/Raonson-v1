import request from "supertest";
import app from "../../src/app.js";
import {
  connectTestDB,
  clearTestDB,
  disconnectTestDB,
} from "../setup/test_database.js";

describe("MODERATION / REPORT THRESHOLD FLOW", () => {
  let tokenA, tokenB, postId;

  beforeAll(async () => {
    await connectTestDB();

    // User A (author)
    await request(app).post("/auth/register").send({
      username: "report_author",
      email: "author@test.com",
      password: "Password123!",
    });

    const loginA = await request(app).post("/auth/login").send({
      email: "author@test.com",
      password: "Password123!",
    });

    tokenA = loginA.body.accessToken;

    // User B (reporter)
    await request(app).post("/auth/register").send({
      username: "report_user",
      email: "reporter@test.com",
      password: "Password123!",
    });

    const loginB = await request(app).post("/auth/login").send({
      email: "reporter@test.com",
      password: "Password123!",
    });

    tokenB = loginB.body.accessToken;

    // Create post
    const post = await request(app)
      .post("/posts")
      .set("Authorization", `Bearer ${tokenA}`)
      .send({
        caption: "Reportable post",
        media: [{ url: "https://test.com/img.jpg", type: "image" }],
      });

    postId = post.body._id;
  });

  afterAll(async () => {
    await clearTestDB();
    await disconnectTestDB();
  });

  it("should flag post after reaching report threshold", async () => {
    const res = await request(app)
      .post(`/posts/${postId}/report`)
      .set("Authorization", `Bearer ${tokenB}`)
      .send({ reason: "spam" });

    expect(res.statusCode).toBe(200);

    const adminView = await request(app)
      .get(`/admin/reports/posts`)
      .set("Authorization", `Bearer ${tokenA}`);

    expect(adminView.statusCode).toBe(200);
    expect(adminView.body.find((p) => p._id === postId)).toBeDefined();
  });
});
