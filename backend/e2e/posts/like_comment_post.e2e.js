import request from "supertest";
import { startServer, stopServer } from "../setup/start_server.js";
import { cleanupDatabase } from "../setup/cleanup.js";

let server;
let token;
let postId;

beforeAll(async () => {
  server = await startServer();

  await request(server).post("/auth/register").send({
    username: "liker",
    email: "liker@test.com",
    password: "LikePost123!",
  });

  const login = await request(server).post("/auth/login").send({
    email: "liker@test.com",
    password: "LikePost123!",
  });

  token = login.body.accessToken;

  const post = await request(server)
    .post("/posts")
    .set("Authorization", `Bearer ${token}`)
    .send({
      caption: "Like me",
      media: [{ url: "https://cdn.raonson/img.png", type: "image" }],
    });

  postId = post.body._id;
});

afterAll(async () => {
  await cleanupDatabase();
  await stopServer();
});

describe("E2E POSTS — Like & Comment", () => {
  test("User likes a post", async () => {
    const res = await request(server)
      .post(`/posts/${postId}/like`)
      .set("Authorization", `Bearer ${token}`)
      .expect(200);

    expect(res.body.liked).toBe(true);
  });

  test("User comments on post", async () => {
    const res = await request(server)
      .post(`/comments`)
      .set("Authorization", `Bearer ${token}`)
      .send({
        targetId: postId,
        content: "Nice post!",
      })
      .expect(200);

    expect(res.body.content).toBe("Nice post!");
  });
});
