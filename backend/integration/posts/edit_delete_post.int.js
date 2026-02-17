import request from "supertest";
import app from "../../src/app.js";
import {
  connectTestDB,
  clearTestDB,
  disconnectTestDB,
} from "../setup/test_database.js";

describe("POSTS / EDIT & DELETE", () => {
  let token, postId;

  beforeAll(async () => {
    await connectTestDB();

    await request(app).post("/auth/register").send({
      username: "editor",
      email: "edit@test.com",
      password: "Password123!",
    });

    const login = await request(app).post("/auth/login").send({
      email: "edit@test.com",
      password: "Password123!",
    });

    token = login.body.accessToken;

    const post = await request(app)
      .post("/posts")
      .set("Authorization", `Bearer ${token}`)
      .send({
        caption: "Old caption",
        media: [{ url: "https://cdn.test/img.jpg", type: "image" }],
      });

    postId = post.body._id;
  });

  afterAll(async () => {
    await clearTestDB();
    await disconnectTestDB();
  });

  it("should edit post caption", async () => {
    const res = await request(app)
      .put(`/posts/${postId}`)
      .set("Authorization", `Bearer ${token}`)
      .send({ caption: "Updated caption" });

    expect(res.statusCode).toBe(200);
    expect(res.body.caption).toBe("Updated caption");
  });

  it("should delete post", async () => {
    const res = await request(app)
      .delete(`/posts/${postId}`)
      .set("Authorization", `Bearer ${token}`);

    expect(res.statusCode).toBe(200);
    expect(res.body.deleted).toBe(true);
  });
});
