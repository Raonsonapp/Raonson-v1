import request from "supertest";
import { startServer, stopServer } from "../setup/start_server.js";
import { cleanupDatabase } from "../setup/cleanup.js";

let server;
let token;

beforeAll(async () => {
  server = await startServer();

  await request(server).post("/auth/register").send({
    username: "expiry_user",
    email: "expiry@test.com",
    password: "Expire123!",
  });

  const login = await request(server).post("/auth/login").send({
    email: "expiry@test.com",
    password: "Expire123!",
  });

  token = login.body.accessToken;
});

afterAll(async () => {
  await cleanupDatabase();
  await stopServer();
});

describe("E2E STORIES — Expiry (24h logic)", () => {
  test("Expired stories are not returned", async () => {
    // create story with backdated timestamp (simulated by admin override)
    await request(server)
      .post("/stories")
      .set("Authorization", `Bearer ${token}`)
      .send({
        mediaUrl: "https://cdn.raonson/old_story.jpg",
        mediaType: "image",
        createdAt: new Date(Date.now() - 1000 * 60 * 60 * 25), // 25h ago
      });

    const res = await request(server)
      .get("/stories")
      .set("Authorization", `Bearer ${token}`)
      .expect(200);

    const allStories = Object.values(res.body).flat();
    expect(allStories.length).toBe(0);
  });
});
