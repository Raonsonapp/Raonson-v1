import request from "supertest";
import { startServer, stopServer } from "../setup/start_server.js";
import { cleanupDatabase } from "../setup/cleanup.js";

let server;
let tokenA;
let tokenB;
let userB;

beforeAll(async () => {
  server = await startServer();

  await request(server).post("/auth/register").send({
    username: "follower",
    email: "follower@test.com",
    password: "Test123!",
  });

  await request(server).post("/auth/register").send({
    username: "followed",
    email: "followed@test.com",
    password: "Test123!",
  });

  const loginA = await request(server).post("/auth/login").send({
    email: "follower@test.com",
    password: "Test123!",
  });
  tokenA = loginA.body.accessToken;

  const loginB = await request(server).post("/auth/login").send({
    email: "followed@test.com",
    password: "Test123!",
  });
  tokenB = loginB.body.accessToken;
  userB = loginB.body.user._id;
});

afterAll(async () => {
  await cleanupDatabase();
  await stopServer();
});

describe("E2E PROFILE — Follow / Unfollow", () => {
  test("Follow user", async () => {
    await request(server)
      .post(`/follow/${userB}`)
      .set("Authorization", `Bearer ${tokenA}`)
      .expect(200);

    const res = await request(server)
      .get(`/profile/${userB}`)
      .set("Authorization", `Bearer ${tokenB}`)
      .expect(200);

    expect(res.body.followersCount).toBe(1);
  });

  test("Unfollow user", async () => {
    await request(server)
      .delete(`/follow/${userB}`)
      .set("Authorization", `Bearer ${tokenA}`)
      .expect(200);

    const res = await request(server)
      .get(`/profile/${userB}`)
      .set("Authorization", `Bearer ${tokenB}`)
      .expect(200);

    expect(res.body.followersCount).toBe(0);
  });
});
