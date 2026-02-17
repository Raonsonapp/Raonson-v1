import request from "supertest";
import app from "../../src/app.js";
import {
  connectTestDB,
  clearTestDB,
  disconnectTestDB,
} from "../setup/test_database.js";

describe("FEED / RANKING FLOW", () => {
  let token, postId;

  beforeAll(async () => {
    await connectTestDB();

    await request(app).post("/auth/register").send({
      username: "ranker",
      email: "rank@test.com",
      password: "Password123!",
    });

    const login = await request(app).post("/auth/login").send({
      email: "rank@test.com",
      password: "Password123!",
    });

    token = login.body.accessToken;

    const post = await request(app)
      .post("/posts")
      .set("Authorization", `Bearer ${token}`)
      .send({
        caption: "Ranking test",
        media: [{ url: "https://cdn.test/rank.jpg", type: "image" }],
      });

    postId = post.body._id;

    // like post multiple times
    for (let i = 0; i < 3; i++) {
      await request(app)
        .post(`/likes/post/${postId}`)
        .set("Authorization", `Bearer ${token}`);
    }
  });

  afterAll(async () => {
    await clearTestDB();
    await disconnectTestDB();
  });

  it("should rank liked post higher", async () => {
    const res = await request(app)
      .get("/feed")
      .set("Authorization", `Bearer ${token}`);

    expect(res.statusCode).toBe(200);
    expect(res.body[0]._id).toBe(postId);
  });
});
