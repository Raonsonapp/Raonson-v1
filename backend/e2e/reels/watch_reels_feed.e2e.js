import request from "supertest";
import { startServer, stopServer } from "../setup/start_server.js";
import { cleanupDatabase } from "../setup/cleanup.js";

let server;
let token;

beforeAll(async () => {
  server = await startServer();

  await request(server).post("/auth/register").send({
    username: "reels_watcher",
    email: "reelswatch@test.com",
    password: "Watch123!",
  });

  const login = await request(server).post("/auth/login").send({
    email: "reelswatch@test.com",
    password: "Watch123!",
  });

  token = login.body.accessToken;

  // seed reels
  await request(server)
    .post("/reels")
    .set("Authorization", `Bearer ${token}`)
    .send({
      mediaUrl: "https://cdn.raonson/reel1.mp4",
      caption: "First reel",
    });

  await request(server)
    .post("/reels")
    .set("Authorization", `Bearer ${token}`)
    .send({
      mediaUrl: "https://cdn.raonson/reel2.mp4",
      caption: "Second reel",
    });
});

afterAll(async () => {
  await cleanupDatabase();
  await stopServer();
});

describe("E2E REELS — Watch Feed", () => {
  test("User loads reels feed", async () => {
    const res = await request(server)
      .get("/reels")
      .set("Authorization", `Bearer ${token}`)
      .expect(200);

    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBeGreaterThanOrEqual(2);
    expect(res.body[0]).toHaveProperty("mediaUrl");
  });
});
