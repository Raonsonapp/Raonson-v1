import request from "supertest";
import { startServer, stopServer } from "../setup/start_server.js";
import { cleanupDatabase } from "../setup/cleanup.js";

let server;
let token;

beforeAll(async () => {
  server = await startServer();

  // create user
  await request(server).post("/auth/register").send({
    username: "feed_user",
    email: "feed_user@test.com",
    password: "FeedPass123!",
  });

  const login = await request(server).post("/auth/login").send({
    email: "feed_user@test.com",
    password: "FeedPass123!",
  });

  token = login.body.accessToken;

  // create posts
  for (let i = 0; i < 15; i++) {
    await request(server)
      .post("/posts")
      .set("Authorization", `Bearer ${token}`)
      .send({
        caption: `Post ${i}`,
        media: [{ url: "https://cdn.raonson/img.png", type: "image" }],
      });
  }
});

afterAll(async () => {
  await cleanupDatabase();
  await stopServer();
});

describe("E2E FEED — Home Feed Scroll", () => {
  test("User scrolls home feed and receives posts", async () => {
    const res = await request(server)
      .get("/feed")
      .set("Authorization", `Bearer ${token}`)
      .expect(200);

    expect(res.body.length).toBeGreaterThan(5);
    expect(res.body[0]).toHaveProperty("caption");
  });
});
