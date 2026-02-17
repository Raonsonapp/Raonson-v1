import request from "supertest";
import app from "../../src/app.js";
import {
  connectTestDB,
  clearTestDB,
  disconnectTestDB,
} from "../setup/test_database.js";

describe("POSTS / LIKE & COMMENT FLOW", () => {
  let token, postId;

  beforeAll(async () => {
    await connectTestDB();

    await request(app).post("/auth/register").send({
      username: "engager",
      email: "engage@test.com",
      password: "Password123!",
    });

    const login = await request(app).post("/auth/login").send({
      email: "engage@test.com",
      password: "Password123!",
    });

    token = login.body.accessToken;

    const post = await request(app)
      .post("/posts")
      .set("Authorization", `Bearer ${token}`)
      .send({
        caption: "Like me",
        media: [{ url: "https://cdn.test/like.jpg", type: "image" }],
      });

    postId = post.body._id;
  });

  afterAll(async () => {
    await clearTestDB();
    await disconnectTestDB();
  });

  it("should like post", async () => {
    const res = await request(app)
      .post(`/likes/post/${postId}`)
      .set("Authorization", `Bearer ${token}`);

    expect(res.statusCode).toBe(200);
    expect(res.body.liked).toBe(true);
  });

  it("should comment on post", async () => {
    const res = await request(app)
      .post(`/comments/post/${postId}`)
      .set("Authorization", `Bearer ${token}`)
      .send({ text: "Nice post!" });

    expect(res.statusCode).toBe(200);
    expect(res.body.text).toBe("Nice post!");
  });
});
