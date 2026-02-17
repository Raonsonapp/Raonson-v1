import request from "supertest";
import { startServer, stopServer } from "../setup/start_server.js";
import { cleanupDatabase } from "../setup/cleanup.js";

let server;
let token;
let postId;

beforeAll(async () => {
  server = await startServer();

  await request(server).post("/auth/register").send({
    username: "saver",
    email: "saver@test.com",
    password: "SavePost123!",
  });

  const login = await request(server).post("/auth/login").send({
    email: "saver@test.com",
    password: "SavePost123!",
  });

  token = login.body.accessToken;

  const post = await request(server)
    .post("/posts")
    .set("Authorization", `Bearer ${token}`)
    .send({
      caption: "Save me",
      media: [{ url: "https://cdn.raonson/img.png", type: "image" }],
    });

  postId = post.body._id;
});

afterAll(async () => {
  await cleanupDatabase();
  await stopServer();
});

describe("E2E POSTS — Save / Unsave", () => {
  test("User saves post", async () => {
    const res = await request(server)
      .post(`/posts/${postId}/save`)
      .set("Authorization", `Bearer ${token}`)
      .expect(200);

    expect(res.body.saved).toBe(true);
  });

  test("User unsaves post", async () => {
    const res = await request(server)
      .post(`/posts/${postId}/save`)
      .set("Authorization", `Bearer ${token}`)
      .expect(200);

    expect(res.body.saved).toBe(false);
  });
});
