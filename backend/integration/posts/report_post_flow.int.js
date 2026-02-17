import request from "supertest";
import app from "../../src/app.js";
import {
  connectTestDB,
  clearTestDB,
  disconnectTestDB,
} from "../setup/test_database.js";

describe("POSTS / REPORT FLOW", () => {
  let token, postId;

  beforeAll(async () => {
    await connectTestDB();

    await request(app).post("/auth/register").send({
      username: "reporter",
      email: "report@test.com",
      password: "Password123!",
    });

    const login = await request(app).post("/auth/login").send({
      email: "report@test.com",
      password: "Password123!",
    });

    token = login.body.accessToken;

    const post = await request(app)
      .post("/posts")
      .set("Authorization", `Bearer ${token}`)
      .send({
        caption: "Report me",
        media: [{ url: "https://cdn.test/report.jpg", type: "image" }],
      });

    postId = post.body._id;
  });

  afterAll(async () => {
    await clearTestDB();
    await disconnectTestDB();
  });

  it("should report post", async () => {
    const res = await request(app)
      .post(`/posts/${postId}/report`)
      .set("Authorization", `Bearer ${token}`)
      .send({ reason: "spam" });

    expect(res.statusCode).toBe(200);
    expect(res.body.reported).toBe(true);
  });
});
