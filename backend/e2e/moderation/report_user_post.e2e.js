import request from "supertest";
import { startServer, stopServer } from "../setup/start_server.js";
import { cleanupDatabase } from "../setup/cleanup.js";

let server;
let tokenA;
let tokenB;
let postId;

beforeAll(async () => {
  server = await startServer();

  // User A (author)
  await request(server).post("/auth/register").send({
    username: "author",
    email: "author@test.com",
    password: "Test123!",
  });

  const loginA = await request(server).post("/auth/login").send({
    email: "author@test.com",
    password: "Test123!",
  });
  tokenA = loginA.body.accessToken;

  // User B (reporter)
  await request(server).post("/auth/register").send({
    username: "reporter",
    email: "reporter@test.com",
    password: "Test123!",
  });

  const loginB = await request(server).post("/auth/login").send({
    email: "reporter@test.com",
    password: "Test123!",
  });
  tokenB = loginB.body.accessToken;

  // Create post by User A
  const postRes = await request(server)
    .post("/posts")
    .set("Authorization", `Bearer ${tokenA}`)
    .send({
      caption: "Offensive content",
      media: [{ url: "https://cdn.raonson/post.jpg", type: "image" }],
    })
    .expect(200);

  postId = postRes.body._id;
});

afterAll(async () => {
  await cleanupDatabase();
  await stopServer();
});

describe("E2E MODERATION — Report Post", () => {
  test("Report a post", async () => {
    const res = await request(server)
      .post(`/posts/${postId}/report`)
      .set("Authorization", `Bearer ${tokenB}`)
      .send({
        reason: "spam",
      })
      .expect(200);

    expect(res.body).toHaveProperty("reported");
    expect(res.body.reported).toBe(true);
  });
});
