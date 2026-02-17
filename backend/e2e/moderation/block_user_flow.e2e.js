import request from "supertest";
import { startServer, stopServer } from "../setup/start_server.js";
import { cleanupDatabase } from "../setup/cleanup.js";

let server;
let tokenA;
let tokenB;
let userBId;

beforeAll(async () => {
  server = await startServer();

  // User A
  await request(server).post("/auth/register").send({
    username: "blocker",
    email: "blocker@test.com",
    password: "Test123!",
  });

  const loginA = await request(server).post("/auth/login").send({
    email: "blocker@test.com",
    password: "Test123!",
  });
  tokenA = loginA.body.accessToken;

  // User B
  await request(server).post("/auth/register").send({
    username: "blocked",
    email: "blocked@test.com",
    password: "Test123!",
  });

  const loginB = await request(server).post("/auth/login").send({
    email: "blocked@test.com",
    password: "Test123!",
  });
  tokenB = loginB.body.accessToken;
  userBId = loginB.body.user._id;
});

afterAll(async () => {
  await cleanupDatabase();
  await stopServer();
});

describe("E2E MODERATION — Block User Flow", () => {
  test("Block user", async () => {
    await request(server)
      .post(`/users/${userBId}/block`)
      .set("Authorization", `Bearer ${tokenA}`)
      .expect(200);

    const res = await request(server)
      .get(`/profile/${userBId}`)
      .set("Authorization", `Bearer ${tokenA}`)
      .expect(403);

    expect(res.body.message).toMatch(/blocked/i);
  });

  test("Blocked user cannot interact", async () => {
    const res = await request(server)
      .post(`/follow/${userBId}`)
      .set("Authorization", `Bearer ${tokenA}`)
      .expect(403);

    expect(res.body.message).toMatch(/blocked/i);
  });
});
