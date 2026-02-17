import request from "supertest";
import { startServer, stopServer } from "../setup/start_server.js";
import { cleanupDatabase } from "../setup/cleanup.js";

let server;
let token;
let reelId;

beforeAll(async () => {
  server = await startServer();

  await request(server).post("/auth/register").send({
    username: "reel_actor",
    email: "reelact@test.com",
    password: "Interact123!",
  });

  const login = await request(server).post("/auth/login").send({
    email: "reelact@test.com",
    password: "Interact123!",
  });

  token = login.body.accessToken;

  const reel = await request(server)
    .post("/reels")
    .set("Authorization", `Bearer ${token}`)
    .send({
      mediaUrl: "https://cdn.raonson/reel_like.mp4",
      caption: "Likeable reel",
    });

  reelId = reel.body._id;
});

afterAll(async () => {
  await cleanupDatabase();
  await stopServer();
});

describe("E2E REELS — Interactions", () => {
  test("User likes a reel", async () => {
    const res = await request(server)
      .post(`/reels/${reelId}/like`)
      .set("Authorization", `Bearer ${token}`)
      .expect(200);

    expect(res.body.liked).toBe(true);
  });

  test("User saves a reel", async () => {
    const res = await request(server)
      .post(`/reels/${reelId}/save`)
      .set("Authorization", `Bearer ${token}`)
      .expect(200);

    expect(res.body.saved).toBe(true);
  });

  test("User adds view to reel", async () => {
    const res = await request(server)
      .post(`/reels/${reelId}/view`)
      .set("Authorization", `Bearer ${token}`)
      .expect(200);

    expect(res.body.views).toBeGreaterThanOrEqual(1);
  });
});
